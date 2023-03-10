CREATE OR REPLACE PACKAGE dd_REST AS

  /*
  // +----------------------------------------------------------------------+
  // | dd_REST - PLSQL to REST procedure                                    |
  // +----------------------------------------------------------------------+
  // | Copyright (C) 2022       http://rasd.sourceforge.net                 |
  // +----------------------------------------------------------------------+
  // | This program is free software; you can redistribute it and/or modify |
  // | it under the terms of the GNU General Public License as published by |
  // | the Free Software Foundation; either version 2 of the License, or    |
  // | (at your option) any later version.                                  |
  // |                                                                      |
  // | This program is distributed in the hope that it will be useful       |
  // | but WITHOUT ANY WARRANTY; without even the implied warranty of       |
  // | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the         |
  // | GNU General Public License for more details.                         |
  // +----------------------------------------------------------------------+
  // | Author: Domen Dolar       <domendolar@users.sourceforge.net>         |
  // |Created : 28.12.2022 10:13:45                                          |
  // |Purpose : Create REST request from PL/SQL or SQL                       |
  // +----------------------------------------------------------------------+
  */

  /*
  STATUS
  28.12.2022 - First version - Domen Dolar
  */

/*
SAMPLE OF USAGE IN SQL


select *
  from json_table(dd_REST.request(method => 'GET',
                                  url    => '/ords/development/DOMEN.DOLAR/!DEMO.rest',
                                  qpr    => '{"query":[{"name":"restrestype", "value": "JSON"}]}',
                                  bearer => '',
                                  hdr    => ''),
                  '$.form.b10[*]'
                  COLUMNS(name varchar2(1000) PATH '$.b10rid',
                          value varchar2(1000) PATH '$.b10rs')) jt


*/
  C_DEBUG boolean := false;
  C_ENVIRONMENT constant varchar2(100) := SYS_CONTEXT('USERENV', 'CON_NAME');
  C_URL constant varchar2(100) := CASE
                                    WHEN C_ENVIRONMENT = 'TWITTER' THEN
                                     'https://api.twitter.com'
                                    ELSE
                                     ''
                                  
                                  END;
  C_WALLET      constant varchar2(100) := ''; --file:/wallet must be empty on autonomous database
  C_WALLETNAME  constant varchar2(100) := 'walletpwd';

  type header IS RECORD(
    name  VARCHAR2(256),
    value VARCHAR2(256));

  type theader is table of header index by binary_integer;

  type query IS RECORD(
    name  VARCHAR2(256),
    value VARCHAR2(256));

  type tquery is table of query index by binary_integer;

  C_TIMEOUT number := 180;

  c_hdr theader := theader(1 => header(name  => 'Content-Type',
                                       value => 'application/json; charset=utf-8'),
                           2 => header(name  => 'User-Agent',
                                       value => 'DD_REST/1.0'));

  FUNCTION request(method IN VARCHAR2, --POST, GET, ...
                   url    IN VARCHAR2, --location of REST service, ....
                   qpr    IN tquery,
                   bearer IN VARCHAR2 default null,
                   hdr    IN theader -- custom header
                   ) return clob;

  FUNCTION request(method IN VARCHAR2, --POST, GET, ...
                   url    IN VARCHAR2, --location of REST service, ....
                   qpr    IN varchar2 default null, --params in json -> {"query":[{"name":"NAME1", "value": "VAL1"},{"name":"NAME2", "value": "VAL2"}]}
                   bearer IN VARCHAR2 default null,
                   hdr    IN varchar2 default null -- header in json -> {"header":[{"name":"NAME1", "value": "VAL1"},{"name":"NAME2", "value": "VAL2"}]}
                   ) return clob;

  PROCEDURE add_query(qpr   IN OUT NOCOPY tquery,
                      name  IN VARCHAR2,
                      value IN VARCHAR2);

  PROCEDURE add_header(hpr   IN OUT NOCOPY theader,
                       name  IN VARCHAR2,
                       value IN VARCHAR2);
  function JSON2SQL(pjson varchar2, prootelement varchar2) return varchar2;

END;
/
CREATE OR REPLACE PACKAGE BODY dd_REST AS

  function to_base64(t in varchar2) return varchar2 is
  begin
    return utl_raw.cast_to_varchar2(utl_encode.base64_encode(utl_raw.cast_to_raw(t)));
  end to_base64;

  function from_base64(t in varchar2) return varchar2 is
  begin
    return utl_raw.cast_to_varchar2(utl_encode.base64_decode(utl_raw.cast_to_raw(t)));
  end from_base64;

  function codeGitToken(p_code varchar2) return varchar2 is
  begin
    return to_base64(p_code);
  end;

  function deCodeGitToken(p_code varchar2) return varchar2 is
  begin
    return from_base64(p_code);
  end;

  function escapeJson(p_content clob) return clob is
    v_return clob := p_content;
  begin
    v_return := replace(v_return, '\', '\\'); --Backslash is replaced with \\
    v_return := replace(v_return, '"', '\"'); --Double quote is replaced with \"
    v_return := replace(v_return, chr(10), '\n'); --Newline is replaced with \n
    v_return := replace(v_return, chr(13), '\r'); --Carriage return is replaced with \r
    v_return := replace(v_return, chr(9), '\t'); --Tab is replaced with \t            
    v_return := replace(v_return, '??', '\u0161');
    v_return := replace(v_return, '??', '\u0111');
    v_return := replace(v_return, '??', '\u010D');
    v_return := replace(v_return, '??', '\u0107');
    v_return := replace(v_return, '??', '\u017E');
    v_return := replace(v_return, '??', '\u0160');
    v_return := replace(v_return, '??', '\u0110');
    v_return := replace(v_return, '??', '\u010C');
    v_return := replace(v_return, '??', '\u0106');
    v_return := replace(v_return, '??', '\u017D');
    --    v_return := replace(v_return, '??', '\u0150'); 
    v_return := replace(v_return, chr(14844051), chr(45)); -- Sign '???'  transformed to right one '-'
    v_return := replace(v_return, '??', '\u00EB');
    v_return := replace(v_return, '??', '\u00CB');
  
    --https://www.utf8-chartable.de/unicode-utf8-table.pl?number=1024&unicodeinhtml=hex
    --v_return := replace(v_return,'!','\u0021');
    --v_return := replace(v_return,'"','\u0022');
    --v_return := replace(v_return,'#','\u0023');
    --v_return := replace(v_return,'$','\u0024');
    --v_return := replace(v_return,'%','\u0025');
    --v_return := replace(v_return,'&','\u0026');
    --v_return := replace(v_return,''','\u0027');
    --v_return := replace(v_return,'(','\u0028');
    --v_return := replace(v_return,')','\u0029');
    --v_return := replace(v_return,'*','\u002A');
    --v_return := replace(v_return,'+','\u002B');
    --v_return := replace(v_return,',','\u002C');
    --v_return := replace(v_return,'-','\u002D');
    --v_return := replace(v_return,'.','\u002E');
    --v_return := replace(v_return,'/','\u002F');
    --v_return := replace(v_return,'0','\u0030');
    --v_return := replace(v_return,'1','\u0031');
    --v_return := replace(v_return,'2','\u0032');
    --v_return := replace(v_return,'3','\u0033');
    --v_return := replace(v_return,'4','\u0034');
    --v_return := replace(v_return,'5','\u0035');
    --v_return := replace(v_return,'6','\u0036');
    --v_return := replace(v_return,'7','\u0037');
    --v_return := replace(v_return,'8','\u0038');
    --v_return := replace(v_return,'9','\u0039');
    --v_return := replace(v_return,':','\u003A');
    --v_return := replace(v_return,';','\u003B');
    --v_return := replace(v_return,'<','\u003C');
    --v_return := replace(v_return,'=','\u003D');
    --v_return := replace(v_return,'>','\u003E');
    --v_return := replace(v_return,'?','\u003F');
    --v_return := replace(v_return,'@','\u0040');
    --v_return := replace(v_return,'A','\u0041');
    --v_return := replace(v_return,'B','\u0042');
    --v_return := replace(v_return,'C','\u0043');
    --v_return := replace(v_return,'D','\u0044');
    --v_return := replace(v_return,'E','\u0045');
    --v_return := replace(v_return,'F','\u0046');
    --v_return := replace(v_return,'G','\u0047');
    --v_return := replace(v_return,'H','\u0048');
    --v_return := replace(v_return,'I','\u0049');
    --v_return := replace(v_return,'J','\u004A');
    --v_return := replace(v_return,'K','\u004B');
    --v_return := replace(v_return,'L','\u004C');
    --v_return := replace(v_return,'M','\u004D');
    --v_return := replace(v_return,'N','\u004E');
    --v_return := replace(v_return,'O','\u004F');
    --v_return := replace(v_return,'P','\u0050');
    --v_return := replace(v_return,'Q','\u0051');
    --v_return := replace(v_return,'R','\u0052');
    --v_return := replace(v_return,'S','\u0053');
    --v_return := replace(v_return,'T','\u0054');
    --v_return := replace(v_return,'U','\u0055');
    --v_return := replace(v_return,'V','\u0056');
    --v_return := replace(v_return,'W','\u0057');
    --v_return := replace(v_return,'X','\u0058');
    --v_return := replace(v_return,'Y','\u0059');
    --v_return := replace(v_return,'Z','\u005A');
    --v_return := replace(v_return,'[','\u005B');
    --v_return := replace(v_return,'\','\u005C');
    --v_return := replace(v_return,']','\u005D');
    --v_return := replace(v_return,'^','\u005E');
    --v_return := replace(v_return,'_','\u005F');
    --v_return := replace(v_return,'`','\u0060');
    --v_return := replace(v_return,'a','\u0061');
    --v_return := replace(v_return,'b','\u0062');
    --v_return := replace(v_return,'c','\u0063');
    --v_return := replace(v_return,'d','\u0064');
    --v_return := replace(v_return,'e','\u0065');
    --v_return := replace(v_return,'f','\u0066');
    --v_return := replace(v_return,'g','\u0067');
    --v_return := replace(v_return,'h','\u0068');
    --v_return := replace(v_return,'i','\u0069');
    --v_return := replace(v_return,'j','\u006A');
    --v_return := replace(v_return,'k','\u006B');
    --v_return := replace(v_return,'l','\u006C');
    --v_return := replace(v_return,'m','\u006D');
    --v_return := replace(v_return,'n','\u006E');
    --v_return := replace(v_return,'o','\u006F');
    --v_return := replace(v_return,'p','\u0070');
    --v_return := replace(v_return,'q','\u0071');
    --v_return := replace(v_return,'r','\u0072');
    --v_return := replace(v_return,'s','\u0073');
    --v_return := replace(v_return,'t','\u0074');
    --v_return := replace(v_return,'u','\u0075');
    --v_return := replace(v_return,'v','\u0076');
    --v_return := replace(v_return,'w','\u0077');
    --v_return := replace(v_return,'x','\u0078');
    --v_return := replace(v_return,'y','\u0079');
    --v_return := replace(v_return,'z','\u007A');
    --v_return := replace(v_return,'{','\u007B');
    --v_return := replace(v_return,'|','\u007C');
    --v_return := replace(v_return,'}','\u007D');
    --v_return := replace(v_return,'~','\u007E');
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00A1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00A2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00A3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00A4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00A5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00A6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00A7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00A8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00A9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00AA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00AB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00AC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00AD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00AE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00AF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00B0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00B1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00B2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00B3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00B4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00B5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00B6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00B7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00B8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00B9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00BA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00BB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00BC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00BD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00BE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00BF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00C0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00C1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00C2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00C3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00C4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00C5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00C6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00C7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00C8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00C9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00CA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00CB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00CC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00CD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00CE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00CF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00D0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00D1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00D2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00D3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00D4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00D5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00D6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00D7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00D8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00D9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00DA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00DB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00DC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00DD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00DE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00DF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00E0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00E1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00E2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00E3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00E4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00E5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00E6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00E7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00E8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00E9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00EA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00EB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00EC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00ED');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00EE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00EF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00F0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00F1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00F2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00F3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00F4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00F5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00F6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00F7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00F8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00F9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00FA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00FB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00FC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00FD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00FE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u00FF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0100');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0101');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0102');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0103');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0104');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0105');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0106');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0107');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0108');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0109');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u010A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u010B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u010C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u010D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u010E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u010F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0110');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0111');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0112');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0113');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0114');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0115');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0116');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0117');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0118');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0119');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u011A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u011B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u011C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u011D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u011E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u011F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0120');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0121');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0122');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0123');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0124');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0125');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0126');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0127');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0128');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0129');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u012A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u012B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u012C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u012D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u012E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u012F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0130');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0131');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0132');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0133');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0134');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0135');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0136');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0137');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0138');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0139');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u013A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u013B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u013C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u013D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u013E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u013F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0140');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0141');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0142');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0143');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0144');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0145');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0146');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0147');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0148');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0149');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u014A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u014B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u014C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u014D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u014E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u014F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0150');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0151');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0152');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0153');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0154');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0155');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0156');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0157');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0158');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0159');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u015A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u015B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u015C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u015D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u015E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u015F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0160');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0161');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0162');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0163');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0164');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0165');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0166');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0167');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0168');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0169');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u016A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u016B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u016C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u016D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u016E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u016F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0170');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0171');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0172');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0173');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0174');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0175');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0176');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0177');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0178');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0179');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u017A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u017B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u017C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u017D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u017E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u017F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0180');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0181');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0182');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0183');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0184');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0185');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0186');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0187');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0188');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0189');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u018A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u018B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u018C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u018D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u018E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u018F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0190');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0191');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0192');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0193');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0194');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0195');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0196');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0197');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0198');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0199');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u019A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u019B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u019C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u019D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u019E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u019F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01A0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01A1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01A2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01A3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01A4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01A5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01A6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01A7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01A8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01A9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01AA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01AB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01AC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01AD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01AE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01AF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01B0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01B1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01B2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01B3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01B4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01B5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01B6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01B7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01B8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01B9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01BA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01BB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01BC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01BD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01BE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01BF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01C0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01C1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01C2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01C3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01C4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01C5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01C6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01C7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01C8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01C9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01CA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01CB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01CC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01CD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01CE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01CF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01D0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01D1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01D2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01D3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01D4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01D5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01D6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01D7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01D8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01D9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01DA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01DB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01DC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01DD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01DE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01DF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01E0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01E1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01E2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01E3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01E4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01E5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01E6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01E7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01E8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01E9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01EA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01EB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01EC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01ED');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01EE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01EF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01F0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01F1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01F2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01F3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01F4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01F5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01F6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01F7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01F8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01F9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01FA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01FB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01FC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01FD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01FE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u01FF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0200');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0201');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0202');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0203');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0204');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0205');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0206');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0207');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0208');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0209');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u020A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u020B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u020C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u020D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u020E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u020F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0210');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0211');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0212');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0213');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0214');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0215');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0216');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0217');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0218');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0219');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u021A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u021B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u021C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u021D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u021E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u021F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0220');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0221');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0222');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0223');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0224');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0225');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0226');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0227');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0228');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0229');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u022A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u022B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u022C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u022D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u022E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u022F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0230');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0231');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0232');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0233');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0234');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0235');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0236');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0237');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0238');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0239');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u023A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u023B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u023C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u023D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u023E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u023F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0240');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0241');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0242');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0243');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0244');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0245');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0246');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0247');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0248');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0249');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u024A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u024B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u024C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u024D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u024E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u024F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0250');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0251');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0252');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0253');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0254');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0255');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0256');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0257');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0258');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0259');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u025A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u025B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u025C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u025D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u025E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u025F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0260');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0261');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0262');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0263');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0264');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0265');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0266');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0267');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0268');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0269');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u026A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u026B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u026C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u026D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u026E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u026F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0270');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0271');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0272');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0273');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0274');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0275');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0276');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0277');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0278');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0279');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u027A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u027B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u027C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u027D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u027E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u027F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0280');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0281');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0282');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0283');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0284');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0285');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0286');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0287');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0288');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0289');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u028A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u028B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u028C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u028D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u028E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u028F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0290');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0291');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0292');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0293');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0294');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0295');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0296');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0297');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0298');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0299');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u029A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u029B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u029C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u029D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u029E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u029F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02A0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02A1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02A2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02A3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02A4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02A5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02A6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02A7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02A8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02A9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02AA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02AB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02AC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02AD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02AE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02AF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02B0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02B1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02B2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02B3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02B4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02B5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02B6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02B7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02B8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02B9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02BA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02BB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02BC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02BD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02BE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02BF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02C0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02C1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02C2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02C3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02C4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02C5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02C6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02C7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02C8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02C9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02CA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02CB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02CC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02CD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02CE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02CF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02D0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02D1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02D2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02D3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02D4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02D5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02D6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02D7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02D8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02D9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02DA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02DB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02DC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02DD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02DE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02DF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02E0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02E1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02E2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02E3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02E4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02E5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02E6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02E7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02E8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02E9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02EA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02EB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02EC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02ED');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02EE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02EF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02F0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02F1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02F2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02F3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02F4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02F5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02F6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02F7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02F8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02F9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02FA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02FB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02FC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02FD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02FE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u02FF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0300');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0301');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0302');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0303');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0304');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0305');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0306');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0307');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0308');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0309');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u030A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u030B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u030C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u030D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u030E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u030F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0310');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0311');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0312');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0313');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0314');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0315');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0316');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0317');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0318');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0319');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u031A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u031B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u031C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u031D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u031E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u031F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0320');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0321');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0322');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0323');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0324');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0325');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0326');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0327');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0328');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0329');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u032A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u032B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u032C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u032D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u032E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u032F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0330');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0331');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0332');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0333');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0334');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0335');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0336');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0337');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0338');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0339');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u033A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u033B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u033C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u033D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u033E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u033F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0340');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0341');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0342');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0343');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0344');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0345');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0346');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0347');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0348');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0349');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u034A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u034B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u034C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u034D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u034E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u034F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0350');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0351');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0352');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0353');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0354');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0355');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0356');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0357');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0358');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0359');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u035A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u035B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u035C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u035D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u035E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u035F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0360');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0361');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0362');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0363');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0364');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0365');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0366');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0367');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0368');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0369');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u036A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u036B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u036C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u036D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u036E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u036F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0370');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0371');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0372');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0373');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0374');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0375');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0376');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0377');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0378');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0379');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u037A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u037B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u037C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u037D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u037E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u037F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0380');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0381');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0382');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0383');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0384');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0385');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0386');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0387');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0388');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0389');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u038A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u038B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u038C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u038D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u038E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u038F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0390');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0391');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0392');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0393');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0394');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0395');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0396');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0397');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0398');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u0399');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u039A');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u039B');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u039C');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u039D');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u039E');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u039F');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03A0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03A1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03A2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03A3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03A4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03A5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03A6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03A7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03A8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03A9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03AA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03AB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03AC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03AD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03AE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03AF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03B0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03B1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03B2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03B3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03B4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03B5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03B6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03B7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03B8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03B9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03BA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03BB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03BC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03BD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03BE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03BF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03C0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03C1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03C2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03C3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03C4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03C5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03C6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03C7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03C8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03C9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03CA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03CB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03CC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03CD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03CE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03CF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03D0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03D1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03D2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03D3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03D4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03D5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03D6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03D7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03D8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03D9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03DA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03DB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03DC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03DD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03DE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03DF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03E0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03E1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03E2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03E3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03E4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03E5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03E6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03E7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03E8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03E9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03EA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03EB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03EC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03ED');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03EE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03EF');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03F0');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03F1');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03F2');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03F3');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03F4');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03F5');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03F6');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03F7');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03F8');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03F9');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03FA');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03FB');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03FC');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03FD');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03FE');
    end if;
    if instr(v_return, '??') > 0 then
      v_return := replace(v_return, '??', '\u03FF');
    end if;
  
    if instr(v_return, chr(49824)) > 0 then
      v_return := replace(v_return, chr(49824), ' ');
    end if;
  
    return v_return;
  
  end;

  PROCEDURE add_query(qpr   IN OUT NOCOPY tquery,
                      name  IN VARCHAR2,
                      value IN VARCHAR2) is
    i integer := qpr.count;
  begin
    qpr(i + 1).name := name;
    qpr(i + 1).value := value;
  end;

  PROCEDURE add_header(hpr   IN OUT NOCOPY theader,
                       name  IN VARCHAR2,
                       value IN VARCHAR2) is
    i integer := hpr.count;
  begin
    hpr(i + 1).name := name;
    hpr(i + 1).value := value;
  end;

  FUNCTION request(method IN VARCHAR2, --POST, GET, ...
                   url    IN VARCHAR2, --location of REST service, ....
                   qpr    IN tquery,
                   bearer IN VARCHAR2 default null,
                   hdr    IN theader -- custom header
                   ) RETURN clob AS
    http_req     utl_http.req;
    http_resp    utl_http.resp;
    reqlength    binary_integer;
    responsebody clob := null;
    resplength   binary_integer;
    buffer       varchar2(32767);
    amount       pls_integer := 2000;
    offset       pls_integer := 1;
    reslength    binary_integer;
    eob          boolean := false;
    requestbody  clob;
    v_url        varchar2(1000);
  begin
  
    if c_debug then
      dbms_output.put_line('============================================');
    end if;
  
    utl_http.set_transfer_timeout(C_TIMEOUT);
  
    UTL_HTTP.set_wallet(C_WALLET, C_WALLETNAME);
 
   if instr(upper(url), 'HTTP') = 0 then
      v_url := C_URL || url;
    else
      v_url := url;
    end if;
  
    if qpr.count > 0 then
    
      for i in 1 .. qpr.count loop
      
        if i = 1 and instr(v_url, '?') = 0 then
          v_url := v_url || '?';
        else
          v_url := v_url || '&';
        end if;
      
        v_url := v_url || qpr(i).name || '=' ||
                 --utl_url.escape(qpr(i).value, true);
                 qpr(i).value;
      end loop;
    
    end if;
  
    if c_debug then
      dbms_output.put_line('METHOD: ' || method || ' URL: ' || v_url);
    end if;
  
    http_req := utl_http.begin_request(v_url, method, 'HTTP/1.1');
  
    for i in 1 .. c_hdr.count loop
      utl_http.set_header(http_req, c_hdr(i).name, c_hdr(i).value);
    end loop;
    if bearer is not null then
      utl_http.set_header(http_req, 'Authorization', 'Bearer ' || bearer);
    end if;
    for i in 1 .. hdr.count loop
      utl_http.set_header(http_req, hdr(i).name, hdr(i).value);
    end loop;
  
    if c_debug then
      dbms_output.put_line('============================================');
    end if;
  
    reqlength := dbms_lob.getlength(requestbody);
    if reqlength > 0 then
      utl_http.set_header(http_req, 'Content-Length', reqlength);
    end if;
    while (offset < reqlength) loop
      dbms_lob.read(requestbody, amount, offset, buffer);
      utl_http.write_text(http_req, buffer);
      if c_debug then
        dbms_output.put_line(buffer);
      end if;
      offset := offset + amount;
    end loop;
    if c_debug then
      dbms_output.put_line('============================================');
    end if;
  
    if c_debug then
      dbms_output.put_line('Before http_resp');
    end if;
  
    DBMS_LOB.CREATETEMPORARY(responsebody, true);
    http_resp := utl_http.get_response(http_req);
  
    if c_debug then
      dbms_output.put_line('After http_resp');
    end if;
  
    while not (eob) loop
      begin
        utl_http.read_text(http_resp, buffer, 32767);
        if buffer is not null and length(buffer) > 0 then
          dbms_lob.writeappend(responsebody, length(buffer), buffer);
        end if;
      exception
        when UTL_HTTP.END_OF_BODY THEN
          eob := true;
      end;
    end loop;
  
    if c_debug then
      dbms_output.put_line('After resp loop');
    end if;
  
    utl_http.end_response(http_resp);
  
    if c_debug then
      dbms_output.put_line('responsebody: ' || length(responsebody));
      dbms_output.put_line('responsebody: ' ||
                           substr(responsebody, 1, 1000));
    end if;
  
    RETURN responsebody;
    DBMS_LOB.freetemporary(responsebody);
  
  exception
    when others then
      raise_application_error('-20000',
                              substr(responsebody, 1, 200) || ' ' ||
                              sqlerrm);
  END;

  FUNCTION request(method IN VARCHAR2, --POST, GET, ...
                   url    IN VARCHAR2, --location of REST service, ....
                   qpr    IN varchar2 default null, --params in json
                   bearer IN VARCHAR2 default null,
                   hdr    IN varchar2 default null -- header in json
                   ) return clob is
    vhe theader;
    vqp tquery;
    i   number := 1;
  begin
  
    if hdr is not null then
      i := 1;
      for r in (select *
                  from json_table(hdr,
                                  '$.header[*]'
                                  COLUMNS(name varchar2(1000) PATH '$.name',
                                          value varchar2(1000) PATH '$.value')) jt) loop
      
        vhe(i).name := r.name;
        vhe(i).value := r.value;
        i := i + 1;
      
      end loop;
    end if;
  
    if qpr is not null then
      i := 1;
      for r in (select *
                  from json_table(qpr,
                                  '$.query[*]'
                                  COLUMNS(name varchar2(1000) PATH '$.name',
                                          value varchar2(1000) PATH '$.value')) jt) loop
      
        vqp(i).name := r.name;
        vqp(i).value := r.value;
        i := i + 1;
      
      end loop;
    end if;
  
    return request(method, url, vqp, bearer, vhe);
  
  end;

 function JSON2SQL(pjson varchar2, prootelement varchar2) return varchar2 is
    -- pjson = JSON string .....
    -- prootelement = like form.b10 ....
    i                 integer;
    i1                integer;
    j                 integer;
    vrootelement      varchar2(100) := substr(prootelement,
                                              instr(prootelement, '.', -1) + 1);
    v_jsonsqltemplate varchar2(32000);
    v_str             varchar2(32000);
    v_columns         varchar2(32000);
    v_colname         varchar2(100);
    v_st_zac          number;
    v_zac             varchar2(32000);
    v_st              number;
    v_kn              number;
  begin
  
    v_jsonsqltemplate := '
  select *
  from json_table(#JSON#,
                  ''$.#ROOT#[*]''
                  COLUMNS(#COLUMNS#)) jt';
    ------------------------
    --READ ELEMENT DATA
    v_zac    := substr(pjson,
                       1,
                       instr(pjson, '"' || vrootelement || '"') - 1);
    v_st_zac := REGEXP_COUNT(v_zac, '{');
    v_st     := instr(pjson, '{', 1, v_st_zac + 1);
    j        := 1;
    i        := 1;
    while i < 100 loop
      v_kn := instr(pjson, '}', v_st, j);
      if REGEXP_COUNT(substr(pjson, v_st, v_kn - v_st + 1), '{') = j then
        exit;
      else
        j := j + 1;
      end if;
      i := i + 1;
    end loop;
    v_str := substr(pjson, v_st + 1, v_kn - v_st - 1);
  
    -- ESCAPE []
    if instr(v_str, '[') > 0 then
      i1 := 1;
      while instr(v_str, '[') > 0 and i1 < 1000 loop
        v_st := instr(v_str, '[');
        j    := 1;
        i    := 1;
        while i < 100 loop
          v_kn := instr(v_str, ']', 1, j);
          if REGEXP_COUNT(substr(v_str, v_st, v_kn - v_st + 1), '\[') = j then
            exit;
          else
            j := j + 1;
          end if;
          i := i + 1;
        end loop;
        v_str := substr(v_str, 1, v_st - 1) || '#!#' ||
                 substr(v_str, v_kn + 1);
        i1    := i1 + 1;
      end loop;
    end if;
    -- ESCAPE {}
    if instr(v_str, '{') > 0 then
      i1 := 1;
      while instr(v_str, '{') > 0 and i1 < 1000 loop
        v_st := instr(v_str, '{');
        j    := 1;
        i    := 1;
        while i < 100 loop
          v_kn := instr(v_str, '}', 1, j);
          if REGEXP_COUNT(substr(v_str, v_st, v_kn - v_st + 1), '{') = j then
            exit;
          else
            j := j + 1;
          end if;
          i := i + 1;
        end loop;
        v_str := substr(v_str, 1, v_st - 1) || '#!#' ||
                 substr(v_str, v_kn + 1);
        i1    := i1 + 1;
      end loop;
    end if;
    ------------------------
    -- PREPARE COLUMNS
    i := 1;
    while instr(v_str, ':') > 0 and i < 100 loop
      v_colname := substr(v_str,
                          instr(v_str,
                                '"',
                                (length(v_str) - instr(v_str, ':') + 2) * -1,
                                2) + 1,
                          instr(v_str,
                                '"',
                                (length(v_str) - instr(v_str, ':') + 2) * -1,
                                1) - instr(v_str,
                                           '"',
                                           (length(v_str) - instr(v_str, ':') + 2) * -1,
                                           2) - 1);
      v_str     := substr(v_str, instr(v_str, ':') + 1);
      if substr(ltrim(v_str), 1, 3) = '#!#' then
        v_columns := v_columns || ',' || v_colname ||
                     ' varchar2(1000) FORMAT JSON PATH ''$.' || v_colname || '''';
      else
        v_columns := v_columns || ',' || v_colname ||
                     ' varchar2(1000) PATH ''$.' || v_colname || '''';
      end if;
      i := i + 1;
    end loop;
  
    return replace(replace(replace(v_jsonsqltemplate,
                                   '#ROOT#',
                                   prootelement),
                           '#COLUMNS#',
                           substr(v_columns, 2)),
                   '#JSON#',
                   '''' || pjson || '''');
  
  end;
  
begin
  c_debug := false;

END;
/

