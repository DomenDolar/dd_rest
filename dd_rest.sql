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
    v_return := replace(v_return, 'š', '\u0161');
    v_return := replace(v_return, 'đ', '\u0111');
    v_return := replace(v_return, 'č', '\u010D');
    v_return := replace(v_return, 'ć', '\u0107');
    v_return := replace(v_return, 'ž', '\u017E');
    v_return := replace(v_return, 'Š', '\u0160');
    v_return := replace(v_return, 'Đ', '\u0110');
    v_return := replace(v_return, 'Č', '\u010C');
    v_return := replace(v_return, 'Ć', '\u0106');
    v_return := replace(v_return, 'Ž', '\u017D');
    --    v_return := replace(v_return, 'Ö', '\u0150'); 
    v_return := replace(v_return, chr(14844051), chr(45)); -- Sign '–'  transformed to right one '-'
    v_return := replace(v_return, 'ё', '\u00EB');
    v_return := replace(v_return, 'Ё', '\u00CB');
  
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
    if instr(v_return, '¡') > 0 then
      v_return := replace(v_return, '¡', '\u00A1');
    end if;
    if instr(v_return, '¢') > 0 then
      v_return := replace(v_return, '¢', '\u00A2');
    end if;
    if instr(v_return, '£') > 0 then
      v_return := replace(v_return, '£', '\u00A3');
    end if;
    if instr(v_return, '¤') > 0 then
      v_return := replace(v_return, '¤', '\u00A4');
    end if;
    if instr(v_return, '¥') > 0 then
      v_return := replace(v_return, '¥', '\u00A5');
    end if;
    if instr(v_return, '¦') > 0 then
      v_return := replace(v_return, '¦', '\u00A6');
    end if;
    if instr(v_return, '§') > 0 then
      v_return := replace(v_return, '§', '\u00A7');
    end if;
    if instr(v_return, '¨') > 0 then
      v_return := replace(v_return, '¨', '\u00A8');
    end if;
    if instr(v_return, '©') > 0 then
      v_return := replace(v_return, '©', '\u00A9');
    end if;
    if instr(v_return, 'ª') > 0 then
      v_return := replace(v_return, 'ª', '\u00AA');
    end if;
    if instr(v_return, '«') > 0 then
      v_return := replace(v_return, '«', '\u00AB');
    end if;
    if instr(v_return, '¬') > 0 then
      v_return := replace(v_return, '¬', '\u00AC');
    end if;
    if instr(v_return, '­') > 0 then
      v_return := replace(v_return, '­', '\u00AD');
    end if;
    if instr(v_return, '®') > 0 then
      v_return := replace(v_return, '®', '\u00AE');
    end if;
    if instr(v_return, '¯') > 0 then
      v_return := replace(v_return, '¯', '\u00AF');
    end if;
    if instr(v_return, '°') > 0 then
      v_return := replace(v_return, '°', '\u00B0');
    end if;
    if instr(v_return, '±') > 0 then
      v_return := replace(v_return, '±', '\u00B1');
    end if;
    if instr(v_return, '²') > 0 then
      v_return := replace(v_return, '²', '\u00B2');
    end if;
    if instr(v_return, '³') > 0 then
      v_return := replace(v_return, '³', '\u00B3');
    end if;
    if instr(v_return, '´') > 0 then
      v_return := replace(v_return, '´', '\u00B4');
    end if;
    if instr(v_return, 'µ') > 0 then
      v_return := replace(v_return, 'µ', '\u00B5');
    end if;
    if instr(v_return, '¶') > 0 then
      v_return := replace(v_return, '¶', '\u00B6');
    end if;
    if instr(v_return, '·') > 0 then
      v_return := replace(v_return, '·', '\u00B7');
    end if;
    if instr(v_return, '¸') > 0 then
      v_return := replace(v_return, '¸', '\u00B8');
    end if;
    if instr(v_return, '¹') > 0 then
      v_return := replace(v_return, '¹', '\u00B9');
    end if;
    if instr(v_return, 'º') > 0 then
      v_return := replace(v_return, 'º', '\u00BA');
    end if;
    if instr(v_return, '»') > 0 then
      v_return := replace(v_return, '»', '\u00BB');
    end if;
    if instr(v_return, '¼') > 0 then
      v_return := replace(v_return, '¼', '\u00BC');
    end if;
    if instr(v_return, '½') > 0 then
      v_return := replace(v_return, '½', '\u00BD');
    end if;
    if instr(v_return, '¾') > 0 then
      v_return := replace(v_return, '¾', '\u00BE');
    end if;
    if instr(v_return, '¿') > 0 then
      v_return := replace(v_return, '¿', '\u00BF');
    end if;
    if instr(v_return, 'À') > 0 then
      v_return := replace(v_return, 'À', '\u00C0');
    end if;
    if instr(v_return, 'Á') > 0 then
      v_return := replace(v_return, 'Á', '\u00C1');
    end if;
    if instr(v_return, 'Â') > 0 then
      v_return := replace(v_return, 'Â', '\u00C2');
    end if;
    if instr(v_return, 'Ã') > 0 then
      v_return := replace(v_return, 'Ã', '\u00C3');
    end if;
    if instr(v_return, 'Ä') > 0 then
      v_return := replace(v_return, 'Ä', '\u00C4');
    end if;
    if instr(v_return, 'Å') > 0 then
      v_return := replace(v_return, 'Å', '\u00C5');
    end if;
    if instr(v_return, 'Æ') > 0 then
      v_return := replace(v_return, 'Æ', '\u00C6');
    end if;
    if instr(v_return, 'Ç') > 0 then
      v_return := replace(v_return, 'Ç', '\u00C7');
    end if;
    if instr(v_return, 'È') > 0 then
      v_return := replace(v_return, 'È', '\u00C8');
    end if;
    if instr(v_return, 'É') > 0 then
      v_return := replace(v_return, 'É', '\u00C9');
    end if;
    if instr(v_return, 'Ê') > 0 then
      v_return := replace(v_return, 'Ê', '\u00CA');
    end if;
    if instr(v_return, 'Ë') > 0 then
      v_return := replace(v_return, 'Ë', '\u00CB');
    end if;
    if instr(v_return, 'Ì') > 0 then
      v_return := replace(v_return, 'Ì', '\u00CC');
    end if;
    if instr(v_return, 'Í') > 0 then
      v_return := replace(v_return, 'Í', '\u00CD');
    end if;
    if instr(v_return, 'Î') > 0 then
      v_return := replace(v_return, 'Î', '\u00CE');
    end if;
    if instr(v_return, 'Ï') > 0 then
      v_return := replace(v_return, 'Ï', '\u00CF');
    end if;
    if instr(v_return, 'Ð') > 0 then
      v_return := replace(v_return, 'Ð', '\u00D0');
    end if;
    if instr(v_return, 'Ñ') > 0 then
      v_return := replace(v_return, 'Ñ', '\u00D1');
    end if;
    if instr(v_return, 'Ò') > 0 then
      v_return := replace(v_return, 'Ò', '\u00D2');
    end if;
    if instr(v_return, 'Ó') > 0 then
      v_return := replace(v_return, 'Ó', '\u00D3');
    end if;
    if instr(v_return, 'Ô') > 0 then
      v_return := replace(v_return, 'Ô', '\u00D4');
    end if;
    if instr(v_return, 'Õ') > 0 then
      v_return := replace(v_return, 'Õ', '\u00D5');
    end if;
    if instr(v_return, 'Ö') > 0 then
      v_return := replace(v_return, 'Ö', '\u00D6');
    end if;
    if instr(v_return, '×') > 0 then
      v_return := replace(v_return, '×', '\u00D7');
    end if;
    if instr(v_return, 'Ø') > 0 then
      v_return := replace(v_return, 'Ø', '\u00D8');
    end if;
    if instr(v_return, 'Ù') > 0 then
      v_return := replace(v_return, 'Ù', '\u00D9');
    end if;
    if instr(v_return, 'Ú') > 0 then
      v_return := replace(v_return, 'Ú', '\u00DA');
    end if;
    if instr(v_return, 'Û') > 0 then
      v_return := replace(v_return, 'Û', '\u00DB');
    end if;
    if instr(v_return, 'Ü') > 0 then
      v_return := replace(v_return, 'Ü', '\u00DC');
    end if;
    if instr(v_return, 'Ý') > 0 then
      v_return := replace(v_return, 'Ý', '\u00DD');
    end if;
    if instr(v_return, 'Þ') > 0 then
      v_return := replace(v_return, 'Þ', '\u00DE');
    end if;
    if instr(v_return, 'ß') > 0 then
      v_return := replace(v_return, 'ß', '\u00DF');
    end if;
    if instr(v_return, 'à') > 0 then
      v_return := replace(v_return, 'à', '\u00E0');
    end if;
    if instr(v_return, 'á') > 0 then
      v_return := replace(v_return, 'á', '\u00E1');
    end if;
    if instr(v_return, 'â') > 0 then
      v_return := replace(v_return, 'â', '\u00E2');
    end if;
    if instr(v_return, 'ã') > 0 then
      v_return := replace(v_return, 'ã', '\u00E3');
    end if;
    if instr(v_return, 'ä') > 0 then
      v_return := replace(v_return, 'ä', '\u00E4');
    end if;
    if instr(v_return, 'å') > 0 then
      v_return := replace(v_return, 'å', '\u00E5');
    end if;
    if instr(v_return, 'æ') > 0 then
      v_return := replace(v_return, 'æ', '\u00E6');
    end if;
    if instr(v_return, 'ç') > 0 then
      v_return := replace(v_return, 'ç', '\u00E7');
    end if;
    if instr(v_return, 'è') > 0 then
      v_return := replace(v_return, 'è', '\u00E8');
    end if;
    if instr(v_return, 'é') > 0 then
      v_return := replace(v_return, 'é', '\u00E9');
    end if;
    if instr(v_return, 'ê') > 0 then
      v_return := replace(v_return, 'ê', '\u00EA');
    end if;
    if instr(v_return, 'ë') > 0 then
      v_return := replace(v_return, 'ë', '\u00EB');
    end if;
    if instr(v_return, 'ì') > 0 then
      v_return := replace(v_return, 'ì', '\u00EC');
    end if;
    if instr(v_return, 'í') > 0 then
      v_return := replace(v_return, 'í', '\u00ED');
    end if;
    if instr(v_return, 'î') > 0 then
      v_return := replace(v_return, 'î', '\u00EE');
    end if;
    if instr(v_return, 'ï') > 0 then
      v_return := replace(v_return, 'ï', '\u00EF');
    end if;
    if instr(v_return, 'ð') > 0 then
      v_return := replace(v_return, 'ð', '\u00F0');
    end if;
    if instr(v_return, 'ñ') > 0 then
      v_return := replace(v_return, 'ñ', '\u00F1');
    end if;
    if instr(v_return, 'ò') > 0 then
      v_return := replace(v_return, 'ò', '\u00F2');
    end if;
    if instr(v_return, 'ó') > 0 then
      v_return := replace(v_return, 'ó', '\u00F3');
    end if;
    if instr(v_return, 'ô') > 0 then
      v_return := replace(v_return, 'ô', '\u00F4');
    end if;
    if instr(v_return, 'õ') > 0 then
      v_return := replace(v_return, 'õ', '\u00F5');
    end if;
    if instr(v_return, 'ö') > 0 then
      v_return := replace(v_return, 'ö', '\u00F6');
    end if;
    if instr(v_return, '÷') > 0 then
      v_return := replace(v_return, '÷', '\u00F7');
    end if;
    if instr(v_return, 'ø') > 0 then
      v_return := replace(v_return, 'ø', '\u00F8');
    end if;
    if instr(v_return, 'ù') > 0 then
      v_return := replace(v_return, 'ù', '\u00F9');
    end if;
    if instr(v_return, 'ú') > 0 then
      v_return := replace(v_return, 'ú', '\u00FA');
    end if;
    if instr(v_return, 'û') > 0 then
      v_return := replace(v_return, 'û', '\u00FB');
    end if;
    if instr(v_return, 'ü') > 0 then
      v_return := replace(v_return, 'ü', '\u00FC');
    end if;
    if instr(v_return, 'ý') > 0 then
      v_return := replace(v_return, 'ý', '\u00FD');
    end if;
    if instr(v_return, 'þ') > 0 then
      v_return := replace(v_return, 'þ', '\u00FE');
    end if;
    if instr(v_return, 'ÿ') > 0 then
      v_return := replace(v_return, 'ÿ', '\u00FF');
    end if;
    if instr(v_return, 'Ā') > 0 then
      v_return := replace(v_return, 'Ā', '\u0100');
    end if;
    if instr(v_return, 'ā') > 0 then
      v_return := replace(v_return, 'ā', '\u0101');
    end if;
    if instr(v_return, 'Ă') > 0 then
      v_return := replace(v_return, 'Ă', '\u0102');
    end if;
    if instr(v_return, 'ă') > 0 then
      v_return := replace(v_return, 'ă', '\u0103');
    end if;
    if instr(v_return, 'Ą') > 0 then
      v_return := replace(v_return, 'Ą', '\u0104');
    end if;
    if instr(v_return, 'ą') > 0 then
      v_return := replace(v_return, 'ą', '\u0105');
    end if;
    if instr(v_return, 'Ć') > 0 then
      v_return := replace(v_return, 'Ć', '\u0106');
    end if;
    if instr(v_return, 'ć') > 0 then
      v_return := replace(v_return, 'ć', '\u0107');
    end if;
    if instr(v_return, 'Ĉ') > 0 then
      v_return := replace(v_return, 'Ĉ', '\u0108');
    end if;
    if instr(v_return, 'ĉ') > 0 then
      v_return := replace(v_return, 'ĉ', '\u0109');
    end if;
    if instr(v_return, 'Ċ') > 0 then
      v_return := replace(v_return, 'Ċ', '\u010A');
    end if;
    if instr(v_return, 'ċ') > 0 then
      v_return := replace(v_return, 'ċ', '\u010B');
    end if;
    if instr(v_return, 'Č') > 0 then
      v_return := replace(v_return, 'Č', '\u010C');
    end if;
    if instr(v_return, 'č') > 0 then
      v_return := replace(v_return, 'č', '\u010D');
    end if;
    if instr(v_return, 'Ď') > 0 then
      v_return := replace(v_return, 'Ď', '\u010E');
    end if;
    if instr(v_return, 'ď') > 0 then
      v_return := replace(v_return, 'ď', '\u010F');
    end if;
    if instr(v_return, 'Đ') > 0 then
      v_return := replace(v_return, 'Đ', '\u0110');
    end if;
    if instr(v_return, 'đ') > 0 then
      v_return := replace(v_return, 'đ', '\u0111');
    end if;
    if instr(v_return, 'Ē') > 0 then
      v_return := replace(v_return, 'Ē', '\u0112');
    end if;
    if instr(v_return, 'ē') > 0 then
      v_return := replace(v_return, 'ē', '\u0113');
    end if;
    if instr(v_return, 'Ĕ') > 0 then
      v_return := replace(v_return, 'Ĕ', '\u0114');
    end if;
    if instr(v_return, 'ĕ') > 0 then
      v_return := replace(v_return, 'ĕ', '\u0115');
    end if;
    if instr(v_return, 'Ė') > 0 then
      v_return := replace(v_return, 'Ė', '\u0116');
    end if;
    if instr(v_return, 'ė') > 0 then
      v_return := replace(v_return, 'ė', '\u0117');
    end if;
    if instr(v_return, 'Ę') > 0 then
      v_return := replace(v_return, 'Ę', '\u0118');
    end if;
    if instr(v_return, 'ę') > 0 then
      v_return := replace(v_return, 'ę', '\u0119');
    end if;
    if instr(v_return, 'Ě') > 0 then
      v_return := replace(v_return, 'Ě', '\u011A');
    end if;
    if instr(v_return, 'ě') > 0 then
      v_return := replace(v_return, 'ě', '\u011B');
    end if;
    if instr(v_return, 'Ĝ') > 0 then
      v_return := replace(v_return, 'Ĝ', '\u011C');
    end if;
    if instr(v_return, 'ĝ') > 0 then
      v_return := replace(v_return, 'ĝ', '\u011D');
    end if;
    if instr(v_return, 'Ğ') > 0 then
      v_return := replace(v_return, 'Ğ', '\u011E');
    end if;
    if instr(v_return, 'ğ') > 0 then
      v_return := replace(v_return, 'ğ', '\u011F');
    end if;
    if instr(v_return, 'Ġ') > 0 then
      v_return := replace(v_return, 'Ġ', '\u0120');
    end if;
    if instr(v_return, 'ġ') > 0 then
      v_return := replace(v_return, 'ġ', '\u0121');
    end if;
    if instr(v_return, 'Ģ') > 0 then
      v_return := replace(v_return, 'Ģ', '\u0122');
    end if;
    if instr(v_return, 'ģ') > 0 then
      v_return := replace(v_return, 'ģ', '\u0123');
    end if;
    if instr(v_return, 'Ĥ') > 0 then
      v_return := replace(v_return, 'Ĥ', '\u0124');
    end if;
    if instr(v_return, 'ĥ') > 0 then
      v_return := replace(v_return, 'ĥ', '\u0125');
    end if;
    if instr(v_return, 'Ħ') > 0 then
      v_return := replace(v_return, 'Ħ', '\u0126');
    end if;
    if instr(v_return, 'ħ') > 0 then
      v_return := replace(v_return, 'ħ', '\u0127');
    end if;
    if instr(v_return, 'Ĩ') > 0 then
      v_return := replace(v_return, 'Ĩ', '\u0128');
    end if;
    if instr(v_return, 'ĩ') > 0 then
      v_return := replace(v_return, 'ĩ', '\u0129');
    end if;
    if instr(v_return, 'Ī') > 0 then
      v_return := replace(v_return, 'Ī', '\u012A');
    end if;
    if instr(v_return, 'ī') > 0 then
      v_return := replace(v_return, 'ī', '\u012B');
    end if;
    if instr(v_return, 'Ĭ') > 0 then
      v_return := replace(v_return, 'Ĭ', '\u012C');
    end if;
    if instr(v_return, 'ĭ') > 0 then
      v_return := replace(v_return, 'ĭ', '\u012D');
    end if;
    if instr(v_return, 'Į') > 0 then
      v_return := replace(v_return, 'Į', '\u012E');
    end if;
    if instr(v_return, 'į') > 0 then
      v_return := replace(v_return, 'į', '\u012F');
    end if;
    if instr(v_return, 'İ') > 0 then
      v_return := replace(v_return, 'İ', '\u0130');
    end if;
    if instr(v_return, 'ı') > 0 then
      v_return := replace(v_return, 'ı', '\u0131');
    end if;
    if instr(v_return, 'Ĳ') > 0 then
      v_return := replace(v_return, 'Ĳ', '\u0132');
    end if;
    if instr(v_return, 'ĳ') > 0 then
      v_return := replace(v_return, 'ĳ', '\u0133');
    end if;
    if instr(v_return, 'Ĵ') > 0 then
      v_return := replace(v_return, 'Ĵ', '\u0134');
    end if;
    if instr(v_return, 'ĵ') > 0 then
      v_return := replace(v_return, 'ĵ', '\u0135');
    end if;
    if instr(v_return, 'Ķ') > 0 then
      v_return := replace(v_return, 'Ķ', '\u0136');
    end if;
    if instr(v_return, 'ķ') > 0 then
      v_return := replace(v_return, 'ķ', '\u0137');
    end if;
    if instr(v_return, 'ĸ') > 0 then
      v_return := replace(v_return, 'ĸ', '\u0138');
    end if;
    if instr(v_return, 'Ĺ') > 0 then
      v_return := replace(v_return, 'Ĺ', '\u0139');
    end if;
    if instr(v_return, 'ĺ') > 0 then
      v_return := replace(v_return, 'ĺ', '\u013A');
    end if;
    if instr(v_return, 'Ļ') > 0 then
      v_return := replace(v_return, 'Ļ', '\u013B');
    end if;
    if instr(v_return, 'ļ') > 0 then
      v_return := replace(v_return, 'ļ', '\u013C');
    end if;
    if instr(v_return, 'Ľ') > 0 then
      v_return := replace(v_return, 'Ľ', '\u013D');
    end if;
    if instr(v_return, 'ľ') > 0 then
      v_return := replace(v_return, 'ľ', '\u013E');
    end if;
    if instr(v_return, 'Ŀ') > 0 then
      v_return := replace(v_return, 'Ŀ', '\u013F');
    end if;
    if instr(v_return, 'ŀ') > 0 then
      v_return := replace(v_return, 'ŀ', '\u0140');
    end if;
    if instr(v_return, 'Ł') > 0 then
      v_return := replace(v_return, 'Ł', '\u0141');
    end if;
    if instr(v_return, 'ł') > 0 then
      v_return := replace(v_return, 'ł', '\u0142');
    end if;
    if instr(v_return, 'Ń') > 0 then
      v_return := replace(v_return, 'Ń', '\u0143');
    end if;
    if instr(v_return, 'ń') > 0 then
      v_return := replace(v_return, 'ń', '\u0144');
    end if;
    if instr(v_return, 'Ņ') > 0 then
      v_return := replace(v_return, 'Ņ', '\u0145');
    end if;
    if instr(v_return, 'ņ') > 0 then
      v_return := replace(v_return, 'ņ', '\u0146');
    end if;
    if instr(v_return, 'Ň') > 0 then
      v_return := replace(v_return, 'Ň', '\u0147');
    end if;
    if instr(v_return, 'ň') > 0 then
      v_return := replace(v_return, 'ň', '\u0148');
    end if;
    if instr(v_return, 'ŉ') > 0 then
      v_return := replace(v_return, 'ŉ', '\u0149');
    end if;
    if instr(v_return, 'Ŋ') > 0 then
      v_return := replace(v_return, 'Ŋ', '\u014A');
    end if;
    if instr(v_return, 'ŋ') > 0 then
      v_return := replace(v_return, 'ŋ', '\u014B');
    end if;
    if instr(v_return, 'Ō') > 0 then
      v_return := replace(v_return, 'Ō', '\u014C');
    end if;
    if instr(v_return, 'ō') > 0 then
      v_return := replace(v_return, 'ō', '\u014D');
    end if;
    if instr(v_return, 'Ŏ') > 0 then
      v_return := replace(v_return, 'Ŏ', '\u014E');
    end if;
    if instr(v_return, 'ŏ') > 0 then
      v_return := replace(v_return, 'ŏ', '\u014F');
    end if;
    if instr(v_return, 'Ő') > 0 then
      v_return := replace(v_return, 'Ő', '\u0150');
    end if;
    if instr(v_return, 'ő') > 0 then
      v_return := replace(v_return, 'ő', '\u0151');
    end if;
    if instr(v_return, 'Œ') > 0 then
      v_return := replace(v_return, 'Œ', '\u0152');
    end if;
    if instr(v_return, 'œ') > 0 then
      v_return := replace(v_return, 'œ', '\u0153');
    end if;
    if instr(v_return, 'Ŕ') > 0 then
      v_return := replace(v_return, 'Ŕ', '\u0154');
    end if;
    if instr(v_return, 'ŕ') > 0 then
      v_return := replace(v_return, 'ŕ', '\u0155');
    end if;
    if instr(v_return, 'Ŗ') > 0 then
      v_return := replace(v_return, 'Ŗ', '\u0156');
    end if;
    if instr(v_return, 'ŗ') > 0 then
      v_return := replace(v_return, 'ŗ', '\u0157');
    end if;
    if instr(v_return, 'Ř') > 0 then
      v_return := replace(v_return, 'Ř', '\u0158');
    end if;
    if instr(v_return, 'ř') > 0 then
      v_return := replace(v_return, 'ř', '\u0159');
    end if;
    if instr(v_return, 'Ś') > 0 then
      v_return := replace(v_return, 'Ś', '\u015A');
    end if;
    if instr(v_return, 'ś') > 0 then
      v_return := replace(v_return, 'ś', '\u015B');
    end if;
    if instr(v_return, 'Ŝ') > 0 then
      v_return := replace(v_return, 'Ŝ', '\u015C');
    end if;
    if instr(v_return, 'ŝ') > 0 then
      v_return := replace(v_return, 'ŝ', '\u015D');
    end if;
    if instr(v_return, 'Ş') > 0 then
      v_return := replace(v_return, 'Ş', '\u015E');
    end if;
    if instr(v_return, 'ş') > 0 then
      v_return := replace(v_return, 'ş', '\u015F');
    end if;
    if instr(v_return, 'Š') > 0 then
      v_return := replace(v_return, 'Š', '\u0160');
    end if;
    if instr(v_return, 'š') > 0 then
      v_return := replace(v_return, 'š', '\u0161');
    end if;
    if instr(v_return, 'Ţ') > 0 then
      v_return := replace(v_return, 'Ţ', '\u0162');
    end if;
    if instr(v_return, 'ţ') > 0 then
      v_return := replace(v_return, 'ţ', '\u0163');
    end if;
    if instr(v_return, 'Ť') > 0 then
      v_return := replace(v_return, 'Ť', '\u0164');
    end if;
    if instr(v_return, 'ť') > 0 then
      v_return := replace(v_return, 'ť', '\u0165');
    end if;
    if instr(v_return, 'Ŧ') > 0 then
      v_return := replace(v_return, 'Ŧ', '\u0166');
    end if;
    if instr(v_return, 'ŧ') > 0 then
      v_return := replace(v_return, 'ŧ', '\u0167');
    end if;
    if instr(v_return, 'Ũ') > 0 then
      v_return := replace(v_return, 'Ũ', '\u0168');
    end if;
    if instr(v_return, 'ũ') > 0 then
      v_return := replace(v_return, 'ũ', '\u0169');
    end if;
    if instr(v_return, 'Ū') > 0 then
      v_return := replace(v_return, 'Ū', '\u016A');
    end if;
    if instr(v_return, 'ū') > 0 then
      v_return := replace(v_return, 'ū', '\u016B');
    end if;
    if instr(v_return, 'Ŭ') > 0 then
      v_return := replace(v_return, 'Ŭ', '\u016C');
    end if;
    if instr(v_return, 'ŭ') > 0 then
      v_return := replace(v_return, 'ŭ', '\u016D');
    end if;
    if instr(v_return, 'Ů') > 0 then
      v_return := replace(v_return, 'Ů', '\u016E');
    end if;
    if instr(v_return, 'ů') > 0 then
      v_return := replace(v_return, 'ů', '\u016F');
    end if;
    if instr(v_return, 'Ű') > 0 then
      v_return := replace(v_return, 'Ű', '\u0170');
    end if;
    if instr(v_return, 'ű') > 0 then
      v_return := replace(v_return, 'ű', '\u0171');
    end if;
    if instr(v_return, 'Ų') > 0 then
      v_return := replace(v_return, 'Ų', '\u0172');
    end if;
    if instr(v_return, 'ų') > 0 then
      v_return := replace(v_return, 'ų', '\u0173');
    end if;
    if instr(v_return, 'Ŵ') > 0 then
      v_return := replace(v_return, 'Ŵ', '\u0174');
    end if;
    if instr(v_return, 'ŵ') > 0 then
      v_return := replace(v_return, 'ŵ', '\u0175');
    end if;
    if instr(v_return, 'Ŷ') > 0 then
      v_return := replace(v_return, 'Ŷ', '\u0176');
    end if;
    if instr(v_return, 'ŷ') > 0 then
      v_return := replace(v_return, 'ŷ', '\u0177');
    end if;
    if instr(v_return, 'Ÿ') > 0 then
      v_return := replace(v_return, 'Ÿ', '\u0178');
    end if;
    if instr(v_return, 'Ź') > 0 then
      v_return := replace(v_return, 'Ź', '\u0179');
    end if;
    if instr(v_return, 'ź') > 0 then
      v_return := replace(v_return, 'ź', '\u017A');
    end if;
    if instr(v_return, 'Ż') > 0 then
      v_return := replace(v_return, 'Ż', '\u017B');
    end if;
    if instr(v_return, 'ż') > 0 then
      v_return := replace(v_return, 'ż', '\u017C');
    end if;
    if instr(v_return, 'Ž') > 0 then
      v_return := replace(v_return, 'Ž', '\u017D');
    end if;
    if instr(v_return, 'ž') > 0 then
      v_return := replace(v_return, 'ž', '\u017E');
    end if;
    if instr(v_return, 'ſ') > 0 then
      v_return := replace(v_return, 'ſ', '\u017F');
    end if;
    if instr(v_return, 'ƀ') > 0 then
      v_return := replace(v_return, 'ƀ', '\u0180');
    end if;
    if instr(v_return, 'Ɓ') > 0 then
      v_return := replace(v_return, 'Ɓ', '\u0181');
    end if;
    if instr(v_return, 'Ƃ') > 0 then
      v_return := replace(v_return, 'Ƃ', '\u0182');
    end if;
    if instr(v_return, 'ƃ') > 0 then
      v_return := replace(v_return, 'ƃ', '\u0183');
    end if;
    if instr(v_return, 'Ƅ') > 0 then
      v_return := replace(v_return, 'Ƅ', '\u0184');
    end if;
    if instr(v_return, 'ƅ') > 0 then
      v_return := replace(v_return, 'ƅ', '\u0185');
    end if;
    if instr(v_return, 'Ɔ') > 0 then
      v_return := replace(v_return, 'Ɔ', '\u0186');
    end if;
    if instr(v_return, 'Ƈ') > 0 then
      v_return := replace(v_return, 'Ƈ', '\u0187');
    end if;
    if instr(v_return, 'ƈ') > 0 then
      v_return := replace(v_return, 'ƈ', '\u0188');
    end if;
    if instr(v_return, 'Ɖ') > 0 then
      v_return := replace(v_return, 'Ɖ', '\u0189');
    end if;
    if instr(v_return, 'Ɗ') > 0 then
      v_return := replace(v_return, 'Ɗ', '\u018A');
    end if;
    if instr(v_return, 'Ƌ') > 0 then
      v_return := replace(v_return, 'Ƌ', '\u018B');
    end if;
    if instr(v_return, 'ƌ') > 0 then
      v_return := replace(v_return, 'ƌ', '\u018C');
    end if;
    if instr(v_return, 'ƍ') > 0 then
      v_return := replace(v_return, 'ƍ', '\u018D');
    end if;
    if instr(v_return, 'Ǝ') > 0 then
      v_return := replace(v_return, 'Ǝ', '\u018E');
    end if;
    if instr(v_return, 'Ə') > 0 then
      v_return := replace(v_return, 'Ə', '\u018F');
    end if;
    if instr(v_return, 'Ɛ') > 0 then
      v_return := replace(v_return, 'Ɛ', '\u0190');
    end if;
    if instr(v_return, 'Ƒ') > 0 then
      v_return := replace(v_return, 'Ƒ', '\u0191');
    end if;
    if instr(v_return, 'ƒ') > 0 then
      v_return := replace(v_return, 'ƒ', '\u0192');
    end if;
    if instr(v_return, 'Ɠ') > 0 then
      v_return := replace(v_return, 'Ɠ', '\u0193');
    end if;
    if instr(v_return, 'Ɣ') > 0 then
      v_return := replace(v_return, 'Ɣ', '\u0194');
    end if;
    if instr(v_return, 'ƕ') > 0 then
      v_return := replace(v_return, 'ƕ', '\u0195');
    end if;
    if instr(v_return, 'Ɩ') > 0 then
      v_return := replace(v_return, 'Ɩ', '\u0196');
    end if;
    if instr(v_return, 'Ɨ') > 0 then
      v_return := replace(v_return, 'Ɨ', '\u0197');
    end if;
    if instr(v_return, 'Ƙ') > 0 then
      v_return := replace(v_return, 'Ƙ', '\u0198');
    end if;
    if instr(v_return, 'ƙ') > 0 then
      v_return := replace(v_return, 'ƙ', '\u0199');
    end if;
    if instr(v_return, 'ƚ') > 0 then
      v_return := replace(v_return, 'ƚ', '\u019A');
    end if;
    if instr(v_return, 'ƛ') > 0 then
      v_return := replace(v_return, 'ƛ', '\u019B');
    end if;
    if instr(v_return, 'Ɯ') > 0 then
      v_return := replace(v_return, 'Ɯ', '\u019C');
    end if;
    if instr(v_return, 'Ɲ') > 0 then
      v_return := replace(v_return, 'Ɲ', '\u019D');
    end if;
    if instr(v_return, 'ƞ') > 0 then
      v_return := replace(v_return, 'ƞ', '\u019E');
    end if;
    if instr(v_return, 'Ɵ') > 0 then
      v_return := replace(v_return, 'Ɵ', '\u019F');
    end if;
    if instr(v_return, 'Ơ') > 0 then
      v_return := replace(v_return, 'Ơ', '\u01A0');
    end if;
    if instr(v_return, 'ơ') > 0 then
      v_return := replace(v_return, 'ơ', '\u01A1');
    end if;
    if instr(v_return, 'Ƣ') > 0 then
      v_return := replace(v_return, 'Ƣ', '\u01A2');
    end if;
    if instr(v_return, 'ƣ') > 0 then
      v_return := replace(v_return, 'ƣ', '\u01A3');
    end if;
    if instr(v_return, 'Ƥ') > 0 then
      v_return := replace(v_return, 'Ƥ', '\u01A4');
    end if;
    if instr(v_return, 'ƥ') > 0 then
      v_return := replace(v_return, 'ƥ', '\u01A5');
    end if;
    if instr(v_return, 'Ʀ') > 0 then
      v_return := replace(v_return, 'Ʀ', '\u01A6');
    end if;
    if instr(v_return, 'Ƨ') > 0 then
      v_return := replace(v_return, 'Ƨ', '\u01A7');
    end if;
    if instr(v_return, 'ƨ') > 0 then
      v_return := replace(v_return, 'ƨ', '\u01A8');
    end if;
    if instr(v_return, 'Ʃ') > 0 then
      v_return := replace(v_return, 'Ʃ', '\u01A9');
    end if;
    if instr(v_return, 'ƪ') > 0 then
      v_return := replace(v_return, 'ƪ', '\u01AA');
    end if;
    if instr(v_return, 'ƫ') > 0 then
      v_return := replace(v_return, 'ƫ', '\u01AB');
    end if;
    if instr(v_return, 'Ƭ') > 0 then
      v_return := replace(v_return, 'Ƭ', '\u01AC');
    end if;
    if instr(v_return, 'ƭ') > 0 then
      v_return := replace(v_return, 'ƭ', '\u01AD');
    end if;
    if instr(v_return, 'Ʈ') > 0 then
      v_return := replace(v_return, 'Ʈ', '\u01AE');
    end if;
    if instr(v_return, 'Ư') > 0 then
      v_return := replace(v_return, 'Ư', '\u01AF');
    end if;
    if instr(v_return, 'ư') > 0 then
      v_return := replace(v_return, 'ư', '\u01B0');
    end if;
    if instr(v_return, 'Ʊ') > 0 then
      v_return := replace(v_return, 'Ʊ', '\u01B1');
    end if;
    if instr(v_return, 'Ʋ') > 0 then
      v_return := replace(v_return, 'Ʋ', '\u01B2');
    end if;
    if instr(v_return, 'Ƴ') > 0 then
      v_return := replace(v_return, 'Ƴ', '\u01B3');
    end if;
    if instr(v_return, 'ƴ') > 0 then
      v_return := replace(v_return, 'ƴ', '\u01B4');
    end if;
    if instr(v_return, 'Ƶ') > 0 then
      v_return := replace(v_return, 'Ƶ', '\u01B5');
    end if;
    if instr(v_return, 'ƶ') > 0 then
      v_return := replace(v_return, 'ƶ', '\u01B6');
    end if;
    if instr(v_return, 'Ʒ') > 0 then
      v_return := replace(v_return, 'Ʒ', '\u01B7');
    end if;
    if instr(v_return, 'Ƹ') > 0 then
      v_return := replace(v_return, 'Ƹ', '\u01B8');
    end if;
    if instr(v_return, 'ƹ') > 0 then
      v_return := replace(v_return, 'ƹ', '\u01B9');
    end if;
    if instr(v_return, 'ƺ') > 0 then
      v_return := replace(v_return, 'ƺ', '\u01BA');
    end if;
    if instr(v_return, 'ƻ') > 0 then
      v_return := replace(v_return, 'ƻ', '\u01BB');
    end if;
    if instr(v_return, 'Ƽ') > 0 then
      v_return := replace(v_return, 'Ƽ', '\u01BC');
    end if;
    if instr(v_return, 'ƽ') > 0 then
      v_return := replace(v_return, 'ƽ', '\u01BD');
    end if;
    if instr(v_return, 'ƾ') > 0 then
      v_return := replace(v_return, 'ƾ', '\u01BE');
    end if;
    if instr(v_return, 'ƿ') > 0 then
      v_return := replace(v_return, 'ƿ', '\u01BF');
    end if;
    if instr(v_return, 'ǀ') > 0 then
      v_return := replace(v_return, 'ǀ', '\u01C0');
    end if;
    if instr(v_return, 'ǁ') > 0 then
      v_return := replace(v_return, 'ǁ', '\u01C1');
    end if;
    if instr(v_return, 'ǂ') > 0 then
      v_return := replace(v_return, 'ǂ', '\u01C2');
    end if;
    if instr(v_return, 'ǃ') > 0 then
      v_return := replace(v_return, 'ǃ', '\u01C3');
    end if;
    if instr(v_return, 'Ǆ') > 0 then
      v_return := replace(v_return, 'Ǆ', '\u01C4');
    end if;
    if instr(v_return, 'ǅ') > 0 then
      v_return := replace(v_return, 'ǅ', '\u01C5');
    end if;
    if instr(v_return, 'ǆ') > 0 then
      v_return := replace(v_return, 'ǆ', '\u01C6');
    end if;
    if instr(v_return, 'Ǉ') > 0 then
      v_return := replace(v_return, 'Ǉ', '\u01C7');
    end if;
    if instr(v_return, 'ǈ') > 0 then
      v_return := replace(v_return, 'ǈ', '\u01C8');
    end if;
    if instr(v_return, 'ǉ') > 0 then
      v_return := replace(v_return, 'ǉ', '\u01C9');
    end if;
    if instr(v_return, 'Ǌ') > 0 then
      v_return := replace(v_return, 'Ǌ', '\u01CA');
    end if;
    if instr(v_return, 'ǋ') > 0 then
      v_return := replace(v_return, 'ǋ', '\u01CB');
    end if;
    if instr(v_return, 'ǌ') > 0 then
      v_return := replace(v_return, 'ǌ', '\u01CC');
    end if;
    if instr(v_return, 'Ǎ') > 0 then
      v_return := replace(v_return, 'Ǎ', '\u01CD');
    end if;
    if instr(v_return, 'ǎ') > 0 then
      v_return := replace(v_return, 'ǎ', '\u01CE');
    end if;
    if instr(v_return, 'Ǐ') > 0 then
      v_return := replace(v_return, 'Ǐ', '\u01CF');
    end if;
    if instr(v_return, 'ǐ') > 0 then
      v_return := replace(v_return, 'ǐ', '\u01D0');
    end if;
    if instr(v_return, 'Ǒ') > 0 then
      v_return := replace(v_return, 'Ǒ', '\u01D1');
    end if;
    if instr(v_return, 'ǒ') > 0 then
      v_return := replace(v_return, 'ǒ', '\u01D2');
    end if;
    if instr(v_return, 'Ǔ') > 0 then
      v_return := replace(v_return, 'Ǔ', '\u01D3');
    end if;
    if instr(v_return, 'ǔ') > 0 then
      v_return := replace(v_return, 'ǔ', '\u01D4');
    end if;
    if instr(v_return, 'Ǖ') > 0 then
      v_return := replace(v_return, 'Ǖ', '\u01D5');
    end if;
    if instr(v_return, 'ǖ') > 0 then
      v_return := replace(v_return, 'ǖ', '\u01D6');
    end if;
    if instr(v_return, 'Ǘ') > 0 then
      v_return := replace(v_return, 'Ǘ', '\u01D7');
    end if;
    if instr(v_return, 'ǘ') > 0 then
      v_return := replace(v_return, 'ǘ', '\u01D8');
    end if;
    if instr(v_return, 'Ǚ') > 0 then
      v_return := replace(v_return, 'Ǚ', '\u01D9');
    end if;
    if instr(v_return, 'ǚ') > 0 then
      v_return := replace(v_return, 'ǚ', '\u01DA');
    end if;
    if instr(v_return, 'Ǜ') > 0 then
      v_return := replace(v_return, 'Ǜ', '\u01DB');
    end if;
    if instr(v_return, 'ǜ') > 0 then
      v_return := replace(v_return, 'ǜ', '\u01DC');
    end if;
    if instr(v_return, 'ǝ') > 0 then
      v_return := replace(v_return, 'ǝ', '\u01DD');
    end if;
    if instr(v_return, 'Ǟ') > 0 then
      v_return := replace(v_return, 'Ǟ', '\u01DE');
    end if;
    if instr(v_return, 'ǟ') > 0 then
      v_return := replace(v_return, 'ǟ', '\u01DF');
    end if;
    if instr(v_return, 'Ǡ') > 0 then
      v_return := replace(v_return, 'Ǡ', '\u01E0');
    end if;
    if instr(v_return, 'ǡ') > 0 then
      v_return := replace(v_return, 'ǡ', '\u01E1');
    end if;
    if instr(v_return, 'Ǣ') > 0 then
      v_return := replace(v_return, 'Ǣ', '\u01E2');
    end if;
    if instr(v_return, 'ǣ') > 0 then
      v_return := replace(v_return, 'ǣ', '\u01E3');
    end if;
    if instr(v_return, 'Ǥ') > 0 then
      v_return := replace(v_return, 'Ǥ', '\u01E4');
    end if;
    if instr(v_return, 'ǥ') > 0 then
      v_return := replace(v_return, 'ǥ', '\u01E5');
    end if;
    if instr(v_return, 'Ǧ') > 0 then
      v_return := replace(v_return, 'Ǧ', '\u01E6');
    end if;
    if instr(v_return, 'ǧ') > 0 then
      v_return := replace(v_return, 'ǧ', '\u01E7');
    end if;
    if instr(v_return, 'Ǩ') > 0 then
      v_return := replace(v_return, 'Ǩ', '\u01E8');
    end if;
    if instr(v_return, 'ǩ') > 0 then
      v_return := replace(v_return, 'ǩ', '\u01E9');
    end if;
    if instr(v_return, 'Ǫ') > 0 then
      v_return := replace(v_return, 'Ǫ', '\u01EA');
    end if;
    if instr(v_return, 'ǫ') > 0 then
      v_return := replace(v_return, 'ǫ', '\u01EB');
    end if;
    if instr(v_return, 'Ǭ') > 0 then
      v_return := replace(v_return, 'Ǭ', '\u01EC');
    end if;
    if instr(v_return, 'ǭ') > 0 then
      v_return := replace(v_return, 'ǭ', '\u01ED');
    end if;
    if instr(v_return, 'Ǯ') > 0 then
      v_return := replace(v_return, 'Ǯ', '\u01EE');
    end if;
    if instr(v_return, 'ǯ') > 0 then
      v_return := replace(v_return, 'ǯ', '\u01EF');
    end if;
    if instr(v_return, 'ǰ') > 0 then
      v_return := replace(v_return, 'ǰ', '\u01F0');
    end if;
    if instr(v_return, 'Ǳ') > 0 then
      v_return := replace(v_return, 'Ǳ', '\u01F1');
    end if;
    if instr(v_return, 'ǲ') > 0 then
      v_return := replace(v_return, 'ǲ', '\u01F2');
    end if;
    if instr(v_return, 'ǳ') > 0 then
      v_return := replace(v_return, 'ǳ', '\u01F3');
    end if;
    if instr(v_return, 'Ǵ') > 0 then
      v_return := replace(v_return, 'Ǵ', '\u01F4');
    end if;
    if instr(v_return, 'ǵ') > 0 then
      v_return := replace(v_return, 'ǵ', '\u01F5');
    end if;
    if instr(v_return, 'Ƕ') > 0 then
      v_return := replace(v_return, 'Ƕ', '\u01F6');
    end if;
    if instr(v_return, 'Ƿ') > 0 then
      v_return := replace(v_return, 'Ƿ', '\u01F7');
    end if;
    if instr(v_return, 'Ǹ') > 0 then
      v_return := replace(v_return, 'Ǹ', '\u01F8');
    end if;
    if instr(v_return, 'ǹ') > 0 then
      v_return := replace(v_return, 'ǹ', '\u01F9');
    end if;
    if instr(v_return, 'Ǻ') > 0 then
      v_return := replace(v_return, 'Ǻ', '\u01FA');
    end if;
    if instr(v_return, 'ǻ') > 0 then
      v_return := replace(v_return, 'ǻ', '\u01FB');
    end if;
    if instr(v_return, 'Ǽ') > 0 then
      v_return := replace(v_return, 'Ǽ', '\u01FC');
    end if;
    if instr(v_return, 'ǽ') > 0 then
      v_return := replace(v_return, 'ǽ', '\u01FD');
    end if;
    if instr(v_return, 'Ǿ') > 0 then
      v_return := replace(v_return, 'Ǿ', '\u01FE');
    end if;
    if instr(v_return, 'ǿ') > 0 then
      v_return := replace(v_return, 'ǿ', '\u01FF');
    end if;
    if instr(v_return, 'Ȁ') > 0 then
      v_return := replace(v_return, 'Ȁ', '\u0200');
    end if;
    if instr(v_return, 'ȁ') > 0 then
      v_return := replace(v_return, 'ȁ', '\u0201');
    end if;
    if instr(v_return, 'Ȃ') > 0 then
      v_return := replace(v_return, 'Ȃ', '\u0202');
    end if;
    if instr(v_return, 'ȃ') > 0 then
      v_return := replace(v_return, 'ȃ', '\u0203');
    end if;
    if instr(v_return, 'Ȅ') > 0 then
      v_return := replace(v_return, 'Ȅ', '\u0204');
    end if;
    if instr(v_return, 'ȅ') > 0 then
      v_return := replace(v_return, 'ȅ', '\u0205');
    end if;
    if instr(v_return, 'Ȇ') > 0 then
      v_return := replace(v_return, 'Ȇ', '\u0206');
    end if;
    if instr(v_return, 'ȇ') > 0 then
      v_return := replace(v_return, 'ȇ', '\u0207');
    end if;
    if instr(v_return, 'Ȉ') > 0 then
      v_return := replace(v_return, 'Ȉ', '\u0208');
    end if;
    if instr(v_return, 'ȉ') > 0 then
      v_return := replace(v_return, 'ȉ', '\u0209');
    end if;
    if instr(v_return, 'Ȋ') > 0 then
      v_return := replace(v_return, 'Ȋ', '\u020A');
    end if;
    if instr(v_return, 'ȋ') > 0 then
      v_return := replace(v_return, 'ȋ', '\u020B');
    end if;
    if instr(v_return, 'Ȍ') > 0 then
      v_return := replace(v_return, 'Ȍ', '\u020C');
    end if;
    if instr(v_return, 'ȍ') > 0 then
      v_return := replace(v_return, 'ȍ', '\u020D');
    end if;
    if instr(v_return, 'Ȏ') > 0 then
      v_return := replace(v_return, 'Ȏ', '\u020E');
    end if;
    if instr(v_return, 'ȏ') > 0 then
      v_return := replace(v_return, 'ȏ', '\u020F');
    end if;
    if instr(v_return, 'Ȑ') > 0 then
      v_return := replace(v_return, 'Ȑ', '\u0210');
    end if;
    if instr(v_return, 'ȑ') > 0 then
      v_return := replace(v_return, 'ȑ', '\u0211');
    end if;
    if instr(v_return, 'Ȓ') > 0 then
      v_return := replace(v_return, 'Ȓ', '\u0212');
    end if;
    if instr(v_return, 'ȓ') > 0 then
      v_return := replace(v_return, 'ȓ', '\u0213');
    end if;
    if instr(v_return, 'Ȕ') > 0 then
      v_return := replace(v_return, 'Ȕ', '\u0214');
    end if;
    if instr(v_return, 'ȕ') > 0 then
      v_return := replace(v_return, 'ȕ', '\u0215');
    end if;
    if instr(v_return, 'Ȗ') > 0 then
      v_return := replace(v_return, 'Ȗ', '\u0216');
    end if;
    if instr(v_return, 'ȗ') > 0 then
      v_return := replace(v_return, 'ȗ', '\u0217');
    end if;
    if instr(v_return, 'Ș') > 0 then
      v_return := replace(v_return, 'Ș', '\u0218');
    end if;
    if instr(v_return, 'ș') > 0 then
      v_return := replace(v_return, 'ș', '\u0219');
    end if;
    if instr(v_return, 'Ț') > 0 then
      v_return := replace(v_return, 'Ț', '\u021A');
    end if;
    if instr(v_return, 'ț') > 0 then
      v_return := replace(v_return, 'ț', '\u021B');
    end if;
    if instr(v_return, 'Ȝ') > 0 then
      v_return := replace(v_return, 'Ȝ', '\u021C');
    end if;
    if instr(v_return, 'ȝ') > 0 then
      v_return := replace(v_return, 'ȝ', '\u021D');
    end if;
    if instr(v_return, 'Ȟ') > 0 then
      v_return := replace(v_return, 'Ȟ', '\u021E');
    end if;
    if instr(v_return, 'ȟ') > 0 then
      v_return := replace(v_return, 'ȟ', '\u021F');
    end if;
    if instr(v_return, 'Ƞ') > 0 then
      v_return := replace(v_return, 'Ƞ', '\u0220');
    end if;
    if instr(v_return, 'ȡ') > 0 then
      v_return := replace(v_return, 'ȡ', '\u0221');
    end if;
    if instr(v_return, 'Ȣ') > 0 then
      v_return := replace(v_return, 'Ȣ', '\u0222');
    end if;
    if instr(v_return, 'ȣ') > 0 then
      v_return := replace(v_return, 'ȣ', '\u0223');
    end if;
    if instr(v_return, 'Ȥ') > 0 then
      v_return := replace(v_return, 'Ȥ', '\u0224');
    end if;
    if instr(v_return, 'ȥ') > 0 then
      v_return := replace(v_return, 'ȥ', '\u0225');
    end if;
    if instr(v_return, 'Ȧ') > 0 then
      v_return := replace(v_return, 'Ȧ', '\u0226');
    end if;
    if instr(v_return, 'ȧ') > 0 then
      v_return := replace(v_return, 'ȧ', '\u0227');
    end if;
    if instr(v_return, 'Ȩ') > 0 then
      v_return := replace(v_return, 'Ȩ', '\u0228');
    end if;
    if instr(v_return, 'ȩ') > 0 then
      v_return := replace(v_return, 'ȩ', '\u0229');
    end if;
    if instr(v_return, 'Ȫ') > 0 then
      v_return := replace(v_return, 'Ȫ', '\u022A');
    end if;
    if instr(v_return, 'ȫ') > 0 then
      v_return := replace(v_return, 'ȫ', '\u022B');
    end if;
    if instr(v_return, 'Ȭ') > 0 then
      v_return := replace(v_return, 'Ȭ', '\u022C');
    end if;
    if instr(v_return, 'ȭ') > 0 then
      v_return := replace(v_return, 'ȭ', '\u022D');
    end if;
    if instr(v_return, 'Ȯ') > 0 then
      v_return := replace(v_return, 'Ȯ', '\u022E');
    end if;
    if instr(v_return, 'ȯ') > 0 then
      v_return := replace(v_return, 'ȯ', '\u022F');
    end if;
    if instr(v_return, 'Ȱ') > 0 then
      v_return := replace(v_return, 'Ȱ', '\u0230');
    end if;
    if instr(v_return, 'ȱ') > 0 then
      v_return := replace(v_return, 'ȱ', '\u0231');
    end if;
    if instr(v_return, 'Ȳ') > 0 then
      v_return := replace(v_return, 'Ȳ', '\u0232');
    end if;
    if instr(v_return, 'ȳ') > 0 then
      v_return := replace(v_return, 'ȳ', '\u0233');
    end if;
    if instr(v_return, 'ȴ') > 0 then
      v_return := replace(v_return, 'ȴ', '\u0234');
    end if;
    if instr(v_return, 'ȵ') > 0 then
      v_return := replace(v_return, 'ȵ', '\u0235');
    end if;
    if instr(v_return, 'ȶ') > 0 then
      v_return := replace(v_return, 'ȶ', '\u0236');
    end if;
    if instr(v_return, 'ȷ') > 0 then
      v_return := replace(v_return, 'ȷ', '\u0237');
    end if;
    if instr(v_return, 'ȸ') > 0 then
      v_return := replace(v_return, 'ȸ', '\u0238');
    end if;
    if instr(v_return, 'ȹ') > 0 then
      v_return := replace(v_return, 'ȹ', '\u0239');
    end if;
    if instr(v_return, 'Ⱥ') > 0 then
      v_return := replace(v_return, 'Ⱥ', '\u023A');
    end if;
    if instr(v_return, 'Ȼ') > 0 then
      v_return := replace(v_return, 'Ȼ', '\u023B');
    end if;
    if instr(v_return, 'ȼ') > 0 then
      v_return := replace(v_return, 'ȼ', '\u023C');
    end if;
    if instr(v_return, 'Ƚ') > 0 then
      v_return := replace(v_return, 'Ƚ', '\u023D');
    end if;
    if instr(v_return, 'Ⱦ') > 0 then
      v_return := replace(v_return, 'Ⱦ', '\u023E');
    end if;
    if instr(v_return, 'ȿ') > 0 then
      v_return := replace(v_return, 'ȿ', '\u023F');
    end if;
    if instr(v_return, 'ɀ') > 0 then
      v_return := replace(v_return, 'ɀ', '\u0240');
    end if;
    if instr(v_return, 'Ɂ') > 0 then
      v_return := replace(v_return, 'Ɂ', '\u0241');
    end if;
    if instr(v_return, 'ɂ') > 0 then
      v_return := replace(v_return, 'ɂ', '\u0242');
    end if;
    if instr(v_return, 'Ƀ') > 0 then
      v_return := replace(v_return, 'Ƀ', '\u0243');
    end if;
    if instr(v_return, 'Ʉ') > 0 then
      v_return := replace(v_return, 'Ʉ', '\u0244');
    end if;
    if instr(v_return, 'Ʌ') > 0 then
      v_return := replace(v_return, 'Ʌ', '\u0245');
    end if;
    if instr(v_return, 'Ɇ') > 0 then
      v_return := replace(v_return, 'Ɇ', '\u0246');
    end if;
    if instr(v_return, 'ɇ') > 0 then
      v_return := replace(v_return, 'ɇ', '\u0247');
    end if;
    if instr(v_return, 'Ɉ') > 0 then
      v_return := replace(v_return, 'Ɉ', '\u0248');
    end if;
    if instr(v_return, 'ɉ') > 0 then
      v_return := replace(v_return, 'ɉ', '\u0249');
    end if;
    if instr(v_return, 'Ɋ') > 0 then
      v_return := replace(v_return, 'Ɋ', '\u024A');
    end if;
    if instr(v_return, 'ɋ') > 0 then
      v_return := replace(v_return, 'ɋ', '\u024B');
    end if;
    if instr(v_return, 'Ɍ') > 0 then
      v_return := replace(v_return, 'Ɍ', '\u024C');
    end if;
    if instr(v_return, 'ɍ') > 0 then
      v_return := replace(v_return, 'ɍ', '\u024D');
    end if;
    if instr(v_return, 'Ɏ') > 0 then
      v_return := replace(v_return, 'Ɏ', '\u024E');
    end if;
    if instr(v_return, 'ɏ') > 0 then
      v_return := replace(v_return, 'ɏ', '\u024F');
    end if;
    if instr(v_return, 'ɐ') > 0 then
      v_return := replace(v_return, 'ɐ', '\u0250');
    end if;
    if instr(v_return, 'ɑ') > 0 then
      v_return := replace(v_return, 'ɑ', '\u0251');
    end if;
    if instr(v_return, 'ɒ') > 0 then
      v_return := replace(v_return, 'ɒ', '\u0252');
    end if;
    if instr(v_return, 'ɓ') > 0 then
      v_return := replace(v_return, 'ɓ', '\u0253');
    end if;
    if instr(v_return, 'ɔ') > 0 then
      v_return := replace(v_return, 'ɔ', '\u0254');
    end if;
    if instr(v_return, 'ɕ') > 0 then
      v_return := replace(v_return, 'ɕ', '\u0255');
    end if;
    if instr(v_return, 'ɖ') > 0 then
      v_return := replace(v_return, 'ɖ', '\u0256');
    end if;
    if instr(v_return, 'ɗ') > 0 then
      v_return := replace(v_return, 'ɗ', '\u0257');
    end if;
    if instr(v_return, 'ɘ') > 0 then
      v_return := replace(v_return, 'ɘ', '\u0258');
    end if;
    if instr(v_return, 'ə') > 0 then
      v_return := replace(v_return, 'ə', '\u0259');
    end if;
    if instr(v_return, 'ɚ') > 0 then
      v_return := replace(v_return, 'ɚ', '\u025A');
    end if;
    if instr(v_return, 'ɛ') > 0 then
      v_return := replace(v_return, 'ɛ', '\u025B');
    end if;
    if instr(v_return, 'ɜ') > 0 then
      v_return := replace(v_return, 'ɜ', '\u025C');
    end if;
    if instr(v_return, 'ɝ') > 0 then
      v_return := replace(v_return, 'ɝ', '\u025D');
    end if;
    if instr(v_return, 'ɞ') > 0 then
      v_return := replace(v_return, 'ɞ', '\u025E');
    end if;
    if instr(v_return, 'ɟ') > 0 then
      v_return := replace(v_return, 'ɟ', '\u025F');
    end if;
    if instr(v_return, 'ɠ') > 0 then
      v_return := replace(v_return, 'ɠ', '\u0260');
    end if;
    if instr(v_return, 'ɡ') > 0 then
      v_return := replace(v_return, 'ɡ', '\u0261');
    end if;
    if instr(v_return, 'ɢ') > 0 then
      v_return := replace(v_return, 'ɢ', '\u0262');
    end if;
    if instr(v_return, 'ɣ') > 0 then
      v_return := replace(v_return, 'ɣ', '\u0263');
    end if;
    if instr(v_return, 'ɤ') > 0 then
      v_return := replace(v_return, 'ɤ', '\u0264');
    end if;
    if instr(v_return, 'ɥ') > 0 then
      v_return := replace(v_return, 'ɥ', '\u0265');
    end if;
    if instr(v_return, 'ɦ') > 0 then
      v_return := replace(v_return, 'ɦ', '\u0266');
    end if;
    if instr(v_return, 'ɧ') > 0 then
      v_return := replace(v_return, 'ɧ', '\u0267');
    end if;
    if instr(v_return, 'ɨ') > 0 then
      v_return := replace(v_return, 'ɨ', '\u0268');
    end if;
    if instr(v_return, 'ɩ') > 0 then
      v_return := replace(v_return, 'ɩ', '\u0269');
    end if;
    if instr(v_return, 'ɪ') > 0 then
      v_return := replace(v_return, 'ɪ', '\u026A');
    end if;
    if instr(v_return, 'ɫ') > 0 then
      v_return := replace(v_return, 'ɫ', '\u026B');
    end if;
    if instr(v_return, 'ɬ') > 0 then
      v_return := replace(v_return, 'ɬ', '\u026C');
    end if;
    if instr(v_return, 'ɭ') > 0 then
      v_return := replace(v_return, 'ɭ', '\u026D');
    end if;
    if instr(v_return, 'ɮ') > 0 then
      v_return := replace(v_return, 'ɮ', '\u026E');
    end if;
    if instr(v_return, 'ɯ') > 0 then
      v_return := replace(v_return, 'ɯ', '\u026F');
    end if;
    if instr(v_return, 'ɰ') > 0 then
      v_return := replace(v_return, 'ɰ', '\u0270');
    end if;
    if instr(v_return, 'ɱ') > 0 then
      v_return := replace(v_return, 'ɱ', '\u0271');
    end if;
    if instr(v_return, 'ɲ') > 0 then
      v_return := replace(v_return, 'ɲ', '\u0272');
    end if;
    if instr(v_return, 'ɳ') > 0 then
      v_return := replace(v_return, 'ɳ', '\u0273');
    end if;
    if instr(v_return, 'ɴ') > 0 then
      v_return := replace(v_return, 'ɴ', '\u0274');
    end if;
    if instr(v_return, 'ɵ') > 0 then
      v_return := replace(v_return, 'ɵ', '\u0275');
    end if;
    if instr(v_return, 'ɶ') > 0 then
      v_return := replace(v_return, 'ɶ', '\u0276');
    end if;
    if instr(v_return, 'ɷ') > 0 then
      v_return := replace(v_return, 'ɷ', '\u0277');
    end if;
    if instr(v_return, 'ɸ') > 0 then
      v_return := replace(v_return, 'ɸ', '\u0278');
    end if;
    if instr(v_return, 'ɹ') > 0 then
      v_return := replace(v_return, 'ɹ', '\u0279');
    end if;
    if instr(v_return, 'ɺ') > 0 then
      v_return := replace(v_return, 'ɺ', '\u027A');
    end if;
    if instr(v_return, 'ɻ') > 0 then
      v_return := replace(v_return, 'ɻ', '\u027B');
    end if;
    if instr(v_return, 'ɼ') > 0 then
      v_return := replace(v_return, 'ɼ', '\u027C');
    end if;
    if instr(v_return, 'ɽ') > 0 then
      v_return := replace(v_return, 'ɽ', '\u027D');
    end if;
    if instr(v_return, 'ɾ') > 0 then
      v_return := replace(v_return, 'ɾ', '\u027E');
    end if;
    if instr(v_return, 'ɿ') > 0 then
      v_return := replace(v_return, 'ɿ', '\u027F');
    end if;
    if instr(v_return, 'ʀ') > 0 then
      v_return := replace(v_return, 'ʀ', '\u0280');
    end if;
    if instr(v_return, 'ʁ') > 0 then
      v_return := replace(v_return, 'ʁ', '\u0281');
    end if;
    if instr(v_return, 'ʂ') > 0 then
      v_return := replace(v_return, 'ʂ', '\u0282');
    end if;
    if instr(v_return, 'ʃ') > 0 then
      v_return := replace(v_return, 'ʃ', '\u0283');
    end if;
    if instr(v_return, 'ʄ') > 0 then
      v_return := replace(v_return, 'ʄ', '\u0284');
    end if;
    if instr(v_return, 'ʅ') > 0 then
      v_return := replace(v_return, 'ʅ', '\u0285');
    end if;
    if instr(v_return, 'ʆ') > 0 then
      v_return := replace(v_return, 'ʆ', '\u0286');
    end if;
    if instr(v_return, 'ʇ') > 0 then
      v_return := replace(v_return, 'ʇ', '\u0287');
    end if;
    if instr(v_return, 'ʈ') > 0 then
      v_return := replace(v_return, 'ʈ', '\u0288');
    end if;
    if instr(v_return, 'ʉ') > 0 then
      v_return := replace(v_return, 'ʉ', '\u0289');
    end if;
    if instr(v_return, 'ʊ') > 0 then
      v_return := replace(v_return, 'ʊ', '\u028A');
    end if;
    if instr(v_return, 'ʋ') > 0 then
      v_return := replace(v_return, 'ʋ', '\u028B');
    end if;
    if instr(v_return, 'ʌ') > 0 then
      v_return := replace(v_return, 'ʌ', '\u028C');
    end if;
    if instr(v_return, 'ʍ') > 0 then
      v_return := replace(v_return, 'ʍ', '\u028D');
    end if;
    if instr(v_return, 'ʎ') > 0 then
      v_return := replace(v_return, 'ʎ', '\u028E');
    end if;
    if instr(v_return, 'ʏ') > 0 then
      v_return := replace(v_return, 'ʏ', '\u028F');
    end if;
    if instr(v_return, 'ʐ') > 0 then
      v_return := replace(v_return, 'ʐ', '\u0290');
    end if;
    if instr(v_return, 'ʑ') > 0 then
      v_return := replace(v_return, 'ʑ', '\u0291');
    end if;
    if instr(v_return, 'ʒ') > 0 then
      v_return := replace(v_return, 'ʒ', '\u0292');
    end if;
    if instr(v_return, 'ʓ') > 0 then
      v_return := replace(v_return, 'ʓ', '\u0293');
    end if;
    if instr(v_return, 'ʔ') > 0 then
      v_return := replace(v_return, 'ʔ', '\u0294');
    end if;
    if instr(v_return, 'ʕ') > 0 then
      v_return := replace(v_return, 'ʕ', '\u0295');
    end if;
    if instr(v_return, 'ʖ') > 0 then
      v_return := replace(v_return, 'ʖ', '\u0296');
    end if;
    if instr(v_return, 'ʗ') > 0 then
      v_return := replace(v_return, 'ʗ', '\u0297');
    end if;
    if instr(v_return, 'ʘ') > 0 then
      v_return := replace(v_return, 'ʘ', '\u0298');
    end if;
    if instr(v_return, 'ʙ') > 0 then
      v_return := replace(v_return, 'ʙ', '\u0299');
    end if;
    if instr(v_return, 'ʚ') > 0 then
      v_return := replace(v_return, 'ʚ', '\u029A');
    end if;
    if instr(v_return, 'ʛ') > 0 then
      v_return := replace(v_return, 'ʛ', '\u029B');
    end if;
    if instr(v_return, 'ʜ') > 0 then
      v_return := replace(v_return, 'ʜ', '\u029C');
    end if;
    if instr(v_return, 'ʝ') > 0 then
      v_return := replace(v_return, 'ʝ', '\u029D');
    end if;
    if instr(v_return, 'ʞ') > 0 then
      v_return := replace(v_return, 'ʞ', '\u029E');
    end if;
    if instr(v_return, 'ʟ') > 0 then
      v_return := replace(v_return, 'ʟ', '\u029F');
    end if;
    if instr(v_return, 'ʠ') > 0 then
      v_return := replace(v_return, 'ʠ', '\u02A0');
    end if;
    if instr(v_return, 'ʡ') > 0 then
      v_return := replace(v_return, 'ʡ', '\u02A1');
    end if;
    if instr(v_return, 'ʢ') > 0 then
      v_return := replace(v_return, 'ʢ', '\u02A2');
    end if;
    if instr(v_return, 'ʣ') > 0 then
      v_return := replace(v_return, 'ʣ', '\u02A3');
    end if;
    if instr(v_return, 'ʤ') > 0 then
      v_return := replace(v_return, 'ʤ', '\u02A4');
    end if;
    if instr(v_return, 'ʥ') > 0 then
      v_return := replace(v_return, 'ʥ', '\u02A5');
    end if;
    if instr(v_return, 'ʦ') > 0 then
      v_return := replace(v_return, 'ʦ', '\u02A6');
    end if;
    if instr(v_return, 'ʧ') > 0 then
      v_return := replace(v_return, 'ʧ', '\u02A7');
    end if;
    if instr(v_return, 'ʨ') > 0 then
      v_return := replace(v_return, 'ʨ', '\u02A8');
    end if;
    if instr(v_return, 'ʩ') > 0 then
      v_return := replace(v_return, 'ʩ', '\u02A9');
    end if;
    if instr(v_return, 'ʪ') > 0 then
      v_return := replace(v_return, 'ʪ', '\u02AA');
    end if;
    if instr(v_return, 'ʫ') > 0 then
      v_return := replace(v_return, 'ʫ', '\u02AB');
    end if;
    if instr(v_return, 'ʬ') > 0 then
      v_return := replace(v_return, 'ʬ', '\u02AC');
    end if;
    if instr(v_return, 'ʭ') > 0 then
      v_return := replace(v_return, 'ʭ', '\u02AD');
    end if;
    if instr(v_return, 'ʮ') > 0 then
      v_return := replace(v_return, 'ʮ', '\u02AE');
    end if;
    if instr(v_return, 'ʯ') > 0 then
      v_return := replace(v_return, 'ʯ', '\u02AF');
    end if;
    if instr(v_return, 'ʰ') > 0 then
      v_return := replace(v_return, 'ʰ', '\u02B0');
    end if;
    if instr(v_return, 'ʱ') > 0 then
      v_return := replace(v_return, 'ʱ', '\u02B1');
    end if;
    if instr(v_return, 'ʲ') > 0 then
      v_return := replace(v_return, 'ʲ', '\u02B2');
    end if;
    if instr(v_return, 'ʳ') > 0 then
      v_return := replace(v_return, 'ʳ', '\u02B3');
    end if;
    if instr(v_return, 'ʴ') > 0 then
      v_return := replace(v_return, 'ʴ', '\u02B4');
    end if;
    if instr(v_return, 'ʵ') > 0 then
      v_return := replace(v_return, 'ʵ', '\u02B5');
    end if;
    if instr(v_return, 'ʶ') > 0 then
      v_return := replace(v_return, 'ʶ', '\u02B6');
    end if;
    if instr(v_return, 'ʷ') > 0 then
      v_return := replace(v_return, 'ʷ', '\u02B7');
    end if;
    if instr(v_return, 'ʸ') > 0 then
      v_return := replace(v_return, 'ʸ', '\u02B8');
    end if;
    if instr(v_return, 'ʹ') > 0 then
      v_return := replace(v_return, 'ʹ', '\u02B9');
    end if;
    if instr(v_return, 'ʺ') > 0 then
      v_return := replace(v_return, 'ʺ', '\u02BA');
    end if;
    if instr(v_return, 'ʻ') > 0 then
      v_return := replace(v_return, 'ʻ', '\u02BB');
    end if;
    if instr(v_return, 'ʼ') > 0 then
      v_return := replace(v_return, 'ʼ', '\u02BC');
    end if;
    if instr(v_return, 'ʽ') > 0 then
      v_return := replace(v_return, 'ʽ', '\u02BD');
    end if;
    if instr(v_return, 'ʾ') > 0 then
      v_return := replace(v_return, 'ʾ', '\u02BE');
    end if;
    if instr(v_return, 'ʿ') > 0 then
      v_return := replace(v_return, 'ʿ', '\u02BF');
    end if;
    if instr(v_return, 'ˀ') > 0 then
      v_return := replace(v_return, 'ˀ', '\u02C0');
    end if;
    if instr(v_return, 'ˁ') > 0 then
      v_return := replace(v_return, 'ˁ', '\u02C1');
    end if;
    if instr(v_return, '˂') > 0 then
      v_return := replace(v_return, '˂', '\u02C2');
    end if;
    if instr(v_return, '˃') > 0 then
      v_return := replace(v_return, '˃', '\u02C3');
    end if;
    if instr(v_return, '˄') > 0 then
      v_return := replace(v_return, '˄', '\u02C4');
    end if;
    if instr(v_return, '˅') > 0 then
      v_return := replace(v_return, '˅', '\u02C5');
    end if;
    if instr(v_return, 'ˆ') > 0 then
      v_return := replace(v_return, 'ˆ', '\u02C6');
    end if;
    if instr(v_return, 'ˇ') > 0 then
      v_return := replace(v_return, 'ˇ', '\u02C7');
    end if;
    if instr(v_return, 'ˈ') > 0 then
      v_return := replace(v_return, 'ˈ', '\u02C8');
    end if;
    if instr(v_return, 'ˉ') > 0 then
      v_return := replace(v_return, 'ˉ', '\u02C9');
    end if;
    if instr(v_return, 'ˊ') > 0 then
      v_return := replace(v_return, 'ˊ', '\u02CA');
    end if;
    if instr(v_return, 'ˋ') > 0 then
      v_return := replace(v_return, 'ˋ', '\u02CB');
    end if;
    if instr(v_return, 'ˌ') > 0 then
      v_return := replace(v_return, 'ˌ', '\u02CC');
    end if;
    if instr(v_return, 'ˍ') > 0 then
      v_return := replace(v_return, 'ˍ', '\u02CD');
    end if;
    if instr(v_return, 'ˎ') > 0 then
      v_return := replace(v_return, 'ˎ', '\u02CE');
    end if;
    if instr(v_return, 'ˏ') > 0 then
      v_return := replace(v_return, 'ˏ', '\u02CF');
    end if;
    if instr(v_return, 'ː') > 0 then
      v_return := replace(v_return, 'ː', '\u02D0');
    end if;
    if instr(v_return, 'ˑ') > 0 then
      v_return := replace(v_return, 'ˑ', '\u02D1');
    end if;
    if instr(v_return, '˒') > 0 then
      v_return := replace(v_return, '˒', '\u02D2');
    end if;
    if instr(v_return, '˓') > 0 then
      v_return := replace(v_return, '˓', '\u02D3');
    end if;
    if instr(v_return, '˔') > 0 then
      v_return := replace(v_return, '˔', '\u02D4');
    end if;
    if instr(v_return, '˕') > 0 then
      v_return := replace(v_return, '˕', '\u02D5');
    end if;
    if instr(v_return, '˖') > 0 then
      v_return := replace(v_return, '˖', '\u02D6');
    end if;
    if instr(v_return, '˗') > 0 then
      v_return := replace(v_return, '˗', '\u02D7');
    end if;
    if instr(v_return, '˘') > 0 then
      v_return := replace(v_return, '˘', '\u02D8');
    end if;
    if instr(v_return, '˙') > 0 then
      v_return := replace(v_return, '˙', '\u02D9');
    end if;
    if instr(v_return, '˚') > 0 then
      v_return := replace(v_return, '˚', '\u02DA');
    end if;
    if instr(v_return, '˛') > 0 then
      v_return := replace(v_return, '˛', '\u02DB');
    end if;
    if instr(v_return, '˜') > 0 then
      v_return := replace(v_return, '˜', '\u02DC');
    end if;
    if instr(v_return, '˝') > 0 then
      v_return := replace(v_return, '˝', '\u02DD');
    end if;
    if instr(v_return, '˞') > 0 then
      v_return := replace(v_return, '˞', '\u02DE');
    end if;
    if instr(v_return, '˟') > 0 then
      v_return := replace(v_return, '˟', '\u02DF');
    end if;
    if instr(v_return, 'ˠ') > 0 then
      v_return := replace(v_return, 'ˠ', '\u02E0');
    end if;
    if instr(v_return, 'ˡ') > 0 then
      v_return := replace(v_return, 'ˡ', '\u02E1');
    end if;
    if instr(v_return, 'ˢ') > 0 then
      v_return := replace(v_return, 'ˢ', '\u02E2');
    end if;
    if instr(v_return, 'ˣ') > 0 then
      v_return := replace(v_return, 'ˣ', '\u02E3');
    end if;
    if instr(v_return, 'ˤ') > 0 then
      v_return := replace(v_return, 'ˤ', '\u02E4');
    end if;
    if instr(v_return, '˥') > 0 then
      v_return := replace(v_return, '˥', '\u02E5');
    end if;
    if instr(v_return, '˦') > 0 then
      v_return := replace(v_return, '˦', '\u02E6');
    end if;
    if instr(v_return, '˧') > 0 then
      v_return := replace(v_return, '˧', '\u02E7');
    end if;
    if instr(v_return, '˨') > 0 then
      v_return := replace(v_return, '˨', '\u02E8');
    end if;
    if instr(v_return, '˩') > 0 then
      v_return := replace(v_return, '˩', '\u02E9');
    end if;
    if instr(v_return, '˪') > 0 then
      v_return := replace(v_return, '˪', '\u02EA');
    end if;
    if instr(v_return, '˫') > 0 then
      v_return := replace(v_return, '˫', '\u02EB');
    end if;
    if instr(v_return, 'ˬ') > 0 then
      v_return := replace(v_return, 'ˬ', '\u02EC');
    end if;
    if instr(v_return, '˭') > 0 then
      v_return := replace(v_return, '˭', '\u02ED');
    end if;
    if instr(v_return, 'ˮ') > 0 then
      v_return := replace(v_return, 'ˮ', '\u02EE');
    end if;
    if instr(v_return, '˯') > 0 then
      v_return := replace(v_return, '˯', '\u02EF');
    end if;
    if instr(v_return, '˰') > 0 then
      v_return := replace(v_return, '˰', '\u02F0');
    end if;
    if instr(v_return, '˱') > 0 then
      v_return := replace(v_return, '˱', '\u02F1');
    end if;
    if instr(v_return, '˲') > 0 then
      v_return := replace(v_return, '˲', '\u02F2');
    end if;
    if instr(v_return, '˳') > 0 then
      v_return := replace(v_return, '˳', '\u02F3');
    end if;
    if instr(v_return, '˴') > 0 then
      v_return := replace(v_return, '˴', '\u02F4');
    end if;
    if instr(v_return, '˵') > 0 then
      v_return := replace(v_return, '˵', '\u02F5');
    end if;
    if instr(v_return, '˶') > 0 then
      v_return := replace(v_return, '˶', '\u02F6');
    end if;
    if instr(v_return, '˷') > 0 then
      v_return := replace(v_return, '˷', '\u02F7');
    end if;
    if instr(v_return, '˸') > 0 then
      v_return := replace(v_return, '˸', '\u02F8');
    end if;
    if instr(v_return, '˹') > 0 then
      v_return := replace(v_return, '˹', '\u02F9');
    end if;
    if instr(v_return, '˺') > 0 then
      v_return := replace(v_return, '˺', '\u02FA');
    end if;
    if instr(v_return, '˻') > 0 then
      v_return := replace(v_return, '˻', '\u02FB');
    end if;
    if instr(v_return, '˼') > 0 then
      v_return := replace(v_return, '˼', '\u02FC');
    end if;
    if instr(v_return, '˽') > 0 then
      v_return := replace(v_return, '˽', '\u02FD');
    end if;
    if instr(v_return, '˾') > 0 then
      v_return := replace(v_return, '˾', '\u02FE');
    end if;
    if instr(v_return, '˿') > 0 then
      v_return := replace(v_return, '˿', '\u02FF');
    end if;
    if instr(v_return, '̀') > 0 then
      v_return := replace(v_return, '̀', '\u0300');
    end if;
    if instr(v_return, '́') > 0 then
      v_return := replace(v_return, '́', '\u0301');
    end if;
    if instr(v_return, '̂') > 0 then
      v_return := replace(v_return, '̂', '\u0302');
    end if;
    if instr(v_return, '̃') > 0 then
      v_return := replace(v_return, '̃', '\u0303');
    end if;
    if instr(v_return, '̄') > 0 then
      v_return := replace(v_return, '̄', '\u0304');
    end if;
    if instr(v_return, '̅') > 0 then
      v_return := replace(v_return, '̅', '\u0305');
    end if;
    if instr(v_return, '̆') > 0 then
      v_return := replace(v_return, '̆', '\u0306');
    end if;
    if instr(v_return, '̇') > 0 then
      v_return := replace(v_return, '̇', '\u0307');
    end if;
    if instr(v_return, '̈') > 0 then
      v_return := replace(v_return, '̈', '\u0308');
    end if;
    if instr(v_return, '̉') > 0 then
      v_return := replace(v_return, '̉', '\u0309');
    end if;
    if instr(v_return, '̊') > 0 then
      v_return := replace(v_return, '̊', '\u030A');
    end if;
    if instr(v_return, '̋') > 0 then
      v_return := replace(v_return, '̋', '\u030B');
    end if;
    if instr(v_return, '̌') > 0 then
      v_return := replace(v_return, '̌', '\u030C');
    end if;
    if instr(v_return, '̍') > 0 then
      v_return := replace(v_return, '̍', '\u030D');
    end if;
    if instr(v_return, '̎') > 0 then
      v_return := replace(v_return, '̎', '\u030E');
    end if;
    if instr(v_return, '̏') > 0 then
      v_return := replace(v_return, '̏', '\u030F');
    end if;
    if instr(v_return, '̐') > 0 then
      v_return := replace(v_return, '̐', '\u0310');
    end if;
    if instr(v_return, '̑') > 0 then
      v_return := replace(v_return, '̑', '\u0311');
    end if;
    if instr(v_return, '̒') > 0 then
      v_return := replace(v_return, '̒', '\u0312');
    end if;
    if instr(v_return, '̓') > 0 then
      v_return := replace(v_return, '̓', '\u0313');
    end if;
    if instr(v_return, '̔') > 0 then
      v_return := replace(v_return, '̔', '\u0314');
    end if;
    if instr(v_return, '̕') > 0 then
      v_return := replace(v_return, '̕', '\u0315');
    end if;
    if instr(v_return, '̖') > 0 then
      v_return := replace(v_return, '̖', '\u0316');
    end if;
    if instr(v_return, '̗') > 0 then
      v_return := replace(v_return, '̗', '\u0317');
    end if;
    if instr(v_return, '̘') > 0 then
      v_return := replace(v_return, '̘', '\u0318');
    end if;
    if instr(v_return, '̙') > 0 then
      v_return := replace(v_return, '̙', '\u0319');
    end if;
    if instr(v_return, '̚') > 0 then
      v_return := replace(v_return, '̚', '\u031A');
    end if;
    if instr(v_return, '̛') > 0 then
      v_return := replace(v_return, '̛', '\u031B');
    end if;
    if instr(v_return, '̜') > 0 then
      v_return := replace(v_return, '̜', '\u031C');
    end if;
    if instr(v_return, '̝') > 0 then
      v_return := replace(v_return, '̝', '\u031D');
    end if;
    if instr(v_return, '̞') > 0 then
      v_return := replace(v_return, '̞', '\u031E');
    end if;
    if instr(v_return, '̟') > 0 then
      v_return := replace(v_return, '̟', '\u031F');
    end if;
    if instr(v_return, '̠') > 0 then
      v_return := replace(v_return, '̠', '\u0320');
    end if;
    if instr(v_return, '̡') > 0 then
      v_return := replace(v_return, '̡', '\u0321');
    end if;
    if instr(v_return, '̢') > 0 then
      v_return := replace(v_return, '̢', '\u0322');
    end if;
    if instr(v_return, '̣') > 0 then
      v_return := replace(v_return, '̣', '\u0323');
    end if;
    if instr(v_return, '̤') > 0 then
      v_return := replace(v_return, '̤', '\u0324');
    end if;
    if instr(v_return, '̥') > 0 then
      v_return := replace(v_return, '̥', '\u0325');
    end if;
    if instr(v_return, '̦') > 0 then
      v_return := replace(v_return, '̦', '\u0326');
    end if;
    if instr(v_return, '̧') > 0 then
      v_return := replace(v_return, '̧', '\u0327');
    end if;
    if instr(v_return, '̨') > 0 then
      v_return := replace(v_return, '̨', '\u0328');
    end if;
    if instr(v_return, '̩') > 0 then
      v_return := replace(v_return, '̩', '\u0329');
    end if;
    if instr(v_return, '̪') > 0 then
      v_return := replace(v_return, '̪', '\u032A');
    end if;
    if instr(v_return, '̫') > 0 then
      v_return := replace(v_return, '̫', '\u032B');
    end if;
    if instr(v_return, '̬') > 0 then
      v_return := replace(v_return, '̬', '\u032C');
    end if;
    if instr(v_return, '̭') > 0 then
      v_return := replace(v_return, '̭', '\u032D');
    end if;
    if instr(v_return, '̮') > 0 then
      v_return := replace(v_return, '̮', '\u032E');
    end if;
    if instr(v_return, '̯') > 0 then
      v_return := replace(v_return, '̯', '\u032F');
    end if;
    if instr(v_return, '̰') > 0 then
      v_return := replace(v_return, '̰', '\u0330');
    end if;
    if instr(v_return, '̱') > 0 then
      v_return := replace(v_return, '̱', '\u0331');
    end if;
    if instr(v_return, '̲') > 0 then
      v_return := replace(v_return, '̲', '\u0332');
    end if;
    if instr(v_return, '̳') > 0 then
      v_return := replace(v_return, '̳', '\u0333');
    end if;
    if instr(v_return, '̴') > 0 then
      v_return := replace(v_return, '̴', '\u0334');
    end if;
    if instr(v_return, '̵') > 0 then
      v_return := replace(v_return, '̵', '\u0335');
    end if;
    if instr(v_return, '̶') > 0 then
      v_return := replace(v_return, '̶', '\u0336');
    end if;
    if instr(v_return, '̷') > 0 then
      v_return := replace(v_return, '̷', '\u0337');
    end if;
    if instr(v_return, '̸') > 0 then
      v_return := replace(v_return, '̸', '\u0338');
    end if;
    if instr(v_return, '̹') > 0 then
      v_return := replace(v_return, '̹', '\u0339');
    end if;
    if instr(v_return, '̺') > 0 then
      v_return := replace(v_return, '̺', '\u033A');
    end if;
    if instr(v_return, '̻') > 0 then
      v_return := replace(v_return, '̻', '\u033B');
    end if;
    if instr(v_return, '̼') > 0 then
      v_return := replace(v_return, '̼', '\u033C');
    end if;
    if instr(v_return, '̽') > 0 then
      v_return := replace(v_return, '̽', '\u033D');
    end if;
    if instr(v_return, '̾') > 0 then
      v_return := replace(v_return, '̾', '\u033E');
    end if;
    if instr(v_return, '̿') > 0 then
      v_return := replace(v_return, '̿', '\u033F');
    end if;
    if instr(v_return, '̀') > 0 then
      v_return := replace(v_return, '̀', '\u0340');
    end if;
    if instr(v_return, '́') > 0 then
      v_return := replace(v_return, '́', '\u0341');
    end if;
    if instr(v_return, '͂') > 0 then
      v_return := replace(v_return, '͂', '\u0342');
    end if;
    if instr(v_return, '̓') > 0 then
      v_return := replace(v_return, '̓', '\u0343');
    end if;
    if instr(v_return, '̈́') > 0 then
      v_return := replace(v_return, '̈́', '\u0344');
    end if;
    if instr(v_return, 'ͅ') > 0 then
      v_return := replace(v_return, 'ͅ', '\u0345');
    end if;
    if instr(v_return, '͆') > 0 then
      v_return := replace(v_return, '͆', '\u0346');
    end if;
    if instr(v_return, '͇') > 0 then
      v_return := replace(v_return, '͇', '\u0347');
    end if;
    if instr(v_return, '͈') > 0 then
      v_return := replace(v_return, '͈', '\u0348');
    end if;
    if instr(v_return, '͉') > 0 then
      v_return := replace(v_return, '͉', '\u0349');
    end if;
    if instr(v_return, '͊') > 0 then
      v_return := replace(v_return, '͊', '\u034A');
    end if;
    if instr(v_return, '͋') > 0 then
      v_return := replace(v_return, '͋', '\u034B');
    end if;
    if instr(v_return, '͌') > 0 then
      v_return := replace(v_return, '͌', '\u034C');
    end if;
    if instr(v_return, '͍') > 0 then
      v_return := replace(v_return, '͍', '\u034D');
    end if;
    if instr(v_return, '͎') > 0 then
      v_return := replace(v_return, '͎', '\u034E');
    end if;
    if instr(v_return, '͏') > 0 then
      v_return := replace(v_return, '͏', '\u034F');
    end if;
    if instr(v_return, '͐') > 0 then
      v_return := replace(v_return, '͐', '\u0350');
    end if;
    if instr(v_return, '͑') > 0 then
      v_return := replace(v_return, '͑', '\u0351');
    end if;
    if instr(v_return, '͒') > 0 then
      v_return := replace(v_return, '͒', '\u0352');
    end if;
    if instr(v_return, '͓') > 0 then
      v_return := replace(v_return, '͓', '\u0353');
    end if;
    if instr(v_return, '͔') > 0 then
      v_return := replace(v_return, '͔', '\u0354');
    end if;
    if instr(v_return, '͕') > 0 then
      v_return := replace(v_return, '͕', '\u0355');
    end if;
    if instr(v_return, '͖') > 0 then
      v_return := replace(v_return, '͖', '\u0356');
    end if;
    if instr(v_return, '͗') > 0 then
      v_return := replace(v_return, '͗', '\u0357');
    end if;
    if instr(v_return, '͘') > 0 then
      v_return := replace(v_return, '͘', '\u0358');
    end if;
    if instr(v_return, '͙') > 0 then
      v_return := replace(v_return, '͙', '\u0359');
    end if;
    if instr(v_return, '͚') > 0 then
      v_return := replace(v_return, '͚', '\u035A');
    end if;
    if instr(v_return, '͛') > 0 then
      v_return := replace(v_return, '͛', '\u035B');
    end if;
    if instr(v_return, '͜') > 0 then
      v_return := replace(v_return, '͜', '\u035C');
    end if;
    if instr(v_return, '͝') > 0 then
      v_return := replace(v_return, '͝', '\u035D');
    end if;
    if instr(v_return, '͞') > 0 then
      v_return := replace(v_return, '͞', '\u035E');
    end if;
    if instr(v_return, '͟') > 0 then
      v_return := replace(v_return, '͟', '\u035F');
    end if;
    if instr(v_return, '͠') > 0 then
      v_return := replace(v_return, '͠', '\u0360');
    end if;
    if instr(v_return, '͡') > 0 then
      v_return := replace(v_return, '͡', '\u0361');
    end if;
    if instr(v_return, '͢') > 0 then
      v_return := replace(v_return, '͢', '\u0362');
    end if;
    if instr(v_return, 'ͣ') > 0 then
      v_return := replace(v_return, 'ͣ', '\u0363');
    end if;
    if instr(v_return, 'ͤ') > 0 then
      v_return := replace(v_return, 'ͤ', '\u0364');
    end if;
    if instr(v_return, 'ͥ') > 0 then
      v_return := replace(v_return, 'ͥ', '\u0365');
    end if;
    if instr(v_return, 'ͦ') > 0 then
      v_return := replace(v_return, 'ͦ', '\u0366');
    end if;
    if instr(v_return, 'ͧ') > 0 then
      v_return := replace(v_return, 'ͧ', '\u0367');
    end if;
    if instr(v_return, 'ͨ') > 0 then
      v_return := replace(v_return, 'ͨ', '\u0368');
    end if;
    if instr(v_return, 'ͩ') > 0 then
      v_return := replace(v_return, 'ͩ', '\u0369');
    end if;
    if instr(v_return, 'ͪ') > 0 then
      v_return := replace(v_return, 'ͪ', '\u036A');
    end if;
    if instr(v_return, 'ͫ') > 0 then
      v_return := replace(v_return, 'ͫ', '\u036B');
    end if;
    if instr(v_return, 'ͬ') > 0 then
      v_return := replace(v_return, 'ͬ', '\u036C');
    end if;
    if instr(v_return, 'ͭ') > 0 then
      v_return := replace(v_return, 'ͭ', '\u036D');
    end if;
    if instr(v_return, 'ͮ') > 0 then
      v_return := replace(v_return, 'ͮ', '\u036E');
    end if;
    if instr(v_return, 'ͯ') > 0 then
      v_return := replace(v_return, 'ͯ', '\u036F');
    end if;
    if instr(v_return, 'Ͱ') > 0 then
      v_return := replace(v_return, 'Ͱ', '\u0370');
    end if;
    if instr(v_return, 'ͱ') > 0 then
      v_return := replace(v_return, 'ͱ', '\u0371');
    end if;
    if instr(v_return, 'Ͳ') > 0 then
      v_return := replace(v_return, 'Ͳ', '\u0372');
    end if;
    if instr(v_return, 'ͳ') > 0 then
      v_return := replace(v_return, 'ͳ', '\u0373');
    end if;
    if instr(v_return, 'ʹ') > 0 then
      v_return := replace(v_return, 'ʹ', '\u0374');
    end if;
    if instr(v_return, '͵') > 0 then
      v_return := replace(v_return, '͵', '\u0375');
    end if;
    if instr(v_return, 'Ͷ') > 0 then
      v_return := replace(v_return, 'Ͷ', '\u0376');
    end if;
    if instr(v_return, 'ͷ') > 0 then
      v_return := replace(v_return, 'ͷ', '\u0377');
    end if;
    if instr(v_return, '͸') > 0 then
      v_return := replace(v_return, '͸', '\u0378');
    end if;
    if instr(v_return, '͹') > 0 then
      v_return := replace(v_return, '͹', '\u0379');
    end if;
    if instr(v_return, 'ͺ') > 0 then
      v_return := replace(v_return, 'ͺ', '\u037A');
    end if;
    if instr(v_return, 'ͻ') > 0 then
      v_return := replace(v_return, 'ͻ', '\u037B');
    end if;
    if instr(v_return, 'ͼ') > 0 then
      v_return := replace(v_return, 'ͼ', '\u037C');
    end if;
    if instr(v_return, 'ͽ') > 0 then
      v_return := replace(v_return, 'ͽ', '\u037D');
    end if;
    if instr(v_return, ';') > 0 then
      v_return := replace(v_return, ';', '\u037E');
    end if;
    if instr(v_return, 'Ϳ') > 0 then
      v_return := replace(v_return, 'Ϳ', '\u037F');
    end if;
    if instr(v_return, '΀') > 0 then
      v_return := replace(v_return, '΀', '\u0380');
    end if;
    if instr(v_return, '΁') > 0 then
      v_return := replace(v_return, '΁', '\u0381');
    end if;
    if instr(v_return, '΂') > 0 then
      v_return := replace(v_return, '΂', '\u0382');
    end if;
    if instr(v_return, '΃') > 0 then
      v_return := replace(v_return, '΃', '\u0383');
    end if;
    if instr(v_return, '΄') > 0 then
      v_return := replace(v_return, '΄', '\u0384');
    end if;
    if instr(v_return, '΅') > 0 then
      v_return := replace(v_return, '΅', '\u0385');
    end if;
    if instr(v_return, 'Ά') > 0 then
      v_return := replace(v_return, 'Ά', '\u0386');
    end if;
    if instr(v_return, '·') > 0 then
      v_return := replace(v_return, '·', '\u0387');
    end if;
    if instr(v_return, 'Έ') > 0 then
      v_return := replace(v_return, 'Έ', '\u0388');
    end if;
    if instr(v_return, 'Ή') > 0 then
      v_return := replace(v_return, 'Ή', '\u0389');
    end if;
    if instr(v_return, 'Ί') > 0 then
      v_return := replace(v_return, 'Ί', '\u038A');
    end if;
    if instr(v_return, '΋') > 0 then
      v_return := replace(v_return, '΋', '\u038B');
    end if;
    if instr(v_return, 'Ό') > 0 then
      v_return := replace(v_return, 'Ό', '\u038C');
    end if;
    if instr(v_return, '΍') > 0 then
      v_return := replace(v_return, '΍', '\u038D');
    end if;
    if instr(v_return, 'Ύ') > 0 then
      v_return := replace(v_return, 'Ύ', '\u038E');
    end if;
    if instr(v_return, 'Ώ') > 0 then
      v_return := replace(v_return, 'Ώ', '\u038F');
    end if;
    if instr(v_return, 'ΐ') > 0 then
      v_return := replace(v_return, 'ΐ', '\u0390');
    end if;
    if instr(v_return, 'Α') > 0 then
      v_return := replace(v_return, 'Α', '\u0391');
    end if;
    if instr(v_return, 'Β') > 0 then
      v_return := replace(v_return, 'Β', '\u0392');
    end if;
    if instr(v_return, 'Γ') > 0 then
      v_return := replace(v_return, 'Γ', '\u0393');
    end if;
    if instr(v_return, 'Δ') > 0 then
      v_return := replace(v_return, 'Δ', '\u0394');
    end if;
    if instr(v_return, 'Ε') > 0 then
      v_return := replace(v_return, 'Ε', '\u0395');
    end if;
    if instr(v_return, 'Ζ') > 0 then
      v_return := replace(v_return, 'Ζ', '\u0396');
    end if;
    if instr(v_return, 'Η') > 0 then
      v_return := replace(v_return, 'Η', '\u0397');
    end if;
    if instr(v_return, 'Θ') > 0 then
      v_return := replace(v_return, 'Θ', '\u0398');
    end if;
    if instr(v_return, 'Ι') > 0 then
      v_return := replace(v_return, 'Ι', '\u0399');
    end if;
    if instr(v_return, 'Κ') > 0 then
      v_return := replace(v_return, 'Κ', '\u039A');
    end if;
    if instr(v_return, 'Λ') > 0 then
      v_return := replace(v_return, 'Λ', '\u039B');
    end if;
    if instr(v_return, 'Μ') > 0 then
      v_return := replace(v_return, 'Μ', '\u039C');
    end if;
    if instr(v_return, 'Ν') > 0 then
      v_return := replace(v_return, 'Ν', '\u039D');
    end if;
    if instr(v_return, 'Ξ') > 0 then
      v_return := replace(v_return, 'Ξ', '\u039E');
    end if;
    if instr(v_return, 'Ο') > 0 then
      v_return := replace(v_return, 'Ο', '\u039F');
    end if;
    if instr(v_return, 'Π') > 0 then
      v_return := replace(v_return, 'Π', '\u03A0');
    end if;
    if instr(v_return, 'Ρ') > 0 then
      v_return := replace(v_return, 'Ρ', '\u03A1');
    end if;
    if instr(v_return, '΢') > 0 then
      v_return := replace(v_return, '΢', '\u03A2');
    end if;
    if instr(v_return, 'Σ') > 0 then
      v_return := replace(v_return, 'Σ', '\u03A3');
    end if;
    if instr(v_return, 'Τ') > 0 then
      v_return := replace(v_return, 'Τ', '\u03A4');
    end if;
    if instr(v_return, 'Υ') > 0 then
      v_return := replace(v_return, 'Υ', '\u03A5');
    end if;
    if instr(v_return, 'Φ') > 0 then
      v_return := replace(v_return, 'Φ', '\u03A6');
    end if;
    if instr(v_return, 'Χ') > 0 then
      v_return := replace(v_return, 'Χ', '\u03A7');
    end if;
    if instr(v_return, 'Ψ') > 0 then
      v_return := replace(v_return, 'Ψ', '\u03A8');
    end if;
    if instr(v_return, 'Ω') > 0 then
      v_return := replace(v_return, 'Ω', '\u03A9');
    end if;
    if instr(v_return, 'Ϊ') > 0 then
      v_return := replace(v_return, 'Ϊ', '\u03AA');
    end if;
    if instr(v_return, 'Ϋ') > 0 then
      v_return := replace(v_return, 'Ϋ', '\u03AB');
    end if;
    if instr(v_return, 'ά') > 0 then
      v_return := replace(v_return, 'ά', '\u03AC');
    end if;
    if instr(v_return, 'έ') > 0 then
      v_return := replace(v_return, 'έ', '\u03AD');
    end if;
    if instr(v_return, 'ή') > 0 then
      v_return := replace(v_return, 'ή', '\u03AE');
    end if;
    if instr(v_return, 'ί') > 0 then
      v_return := replace(v_return, 'ί', '\u03AF');
    end if;
    if instr(v_return, 'ΰ') > 0 then
      v_return := replace(v_return, 'ΰ', '\u03B0');
    end if;
    if instr(v_return, 'α') > 0 then
      v_return := replace(v_return, 'α', '\u03B1');
    end if;
    if instr(v_return, 'β') > 0 then
      v_return := replace(v_return, 'β', '\u03B2');
    end if;
    if instr(v_return, 'γ') > 0 then
      v_return := replace(v_return, 'γ', '\u03B3');
    end if;
    if instr(v_return, 'δ') > 0 then
      v_return := replace(v_return, 'δ', '\u03B4');
    end if;
    if instr(v_return, 'ε') > 0 then
      v_return := replace(v_return, 'ε', '\u03B5');
    end if;
    if instr(v_return, 'ζ') > 0 then
      v_return := replace(v_return, 'ζ', '\u03B6');
    end if;
    if instr(v_return, 'η') > 0 then
      v_return := replace(v_return, 'η', '\u03B7');
    end if;
    if instr(v_return, 'θ') > 0 then
      v_return := replace(v_return, 'θ', '\u03B8');
    end if;
    if instr(v_return, 'ι') > 0 then
      v_return := replace(v_return, 'ι', '\u03B9');
    end if;
    if instr(v_return, 'κ') > 0 then
      v_return := replace(v_return, 'κ', '\u03BA');
    end if;
    if instr(v_return, 'λ') > 0 then
      v_return := replace(v_return, 'λ', '\u03BB');
    end if;
    if instr(v_return, 'μ') > 0 then
      v_return := replace(v_return, 'μ', '\u03BC');
    end if;
    if instr(v_return, 'ν') > 0 then
      v_return := replace(v_return, 'ν', '\u03BD');
    end if;
    if instr(v_return, 'ξ') > 0 then
      v_return := replace(v_return, 'ξ', '\u03BE');
    end if;
    if instr(v_return, 'ο') > 0 then
      v_return := replace(v_return, 'ο', '\u03BF');
    end if;
    if instr(v_return, 'π') > 0 then
      v_return := replace(v_return, 'π', '\u03C0');
    end if;
    if instr(v_return, 'ρ') > 0 then
      v_return := replace(v_return, 'ρ', '\u03C1');
    end if;
    if instr(v_return, 'ς') > 0 then
      v_return := replace(v_return, 'ς', '\u03C2');
    end if;
    if instr(v_return, 'σ') > 0 then
      v_return := replace(v_return, 'σ', '\u03C3');
    end if;
    if instr(v_return, 'τ') > 0 then
      v_return := replace(v_return, 'τ', '\u03C4');
    end if;
    if instr(v_return, 'υ') > 0 then
      v_return := replace(v_return, 'υ', '\u03C5');
    end if;
    if instr(v_return, 'φ') > 0 then
      v_return := replace(v_return, 'φ', '\u03C6');
    end if;
    if instr(v_return, 'χ') > 0 then
      v_return := replace(v_return, 'χ', '\u03C7');
    end if;
    if instr(v_return, 'ψ') > 0 then
      v_return := replace(v_return, 'ψ', '\u03C8');
    end if;
    if instr(v_return, 'ω') > 0 then
      v_return := replace(v_return, 'ω', '\u03C9');
    end if;
    if instr(v_return, 'ϊ') > 0 then
      v_return := replace(v_return, 'ϊ', '\u03CA');
    end if;
    if instr(v_return, 'ϋ') > 0 then
      v_return := replace(v_return, 'ϋ', '\u03CB');
    end if;
    if instr(v_return, 'ό') > 0 then
      v_return := replace(v_return, 'ό', '\u03CC');
    end if;
    if instr(v_return, 'ύ') > 0 then
      v_return := replace(v_return, 'ύ', '\u03CD');
    end if;
    if instr(v_return, 'ώ') > 0 then
      v_return := replace(v_return, 'ώ', '\u03CE');
    end if;
    if instr(v_return, 'Ϗ') > 0 then
      v_return := replace(v_return, 'Ϗ', '\u03CF');
    end if;
    if instr(v_return, 'ϐ') > 0 then
      v_return := replace(v_return, 'ϐ', '\u03D0');
    end if;
    if instr(v_return, 'ϑ') > 0 then
      v_return := replace(v_return, 'ϑ', '\u03D1');
    end if;
    if instr(v_return, 'ϒ') > 0 then
      v_return := replace(v_return, 'ϒ', '\u03D2');
    end if;
    if instr(v_return, 'ϓ') > 0 then
      v_return := replace(v_return, 'ϓ', '\u03D3');
    end if;
    if instr(v_return, 'ϔ') > 0 then
      v_return := replace(v_return, 'ϔ', '\u03D4');
    end if;
    if instr(v_return, 'ϕ') > 0 then
      v_return := replace(v_return, 'ϕ', '\u03D5');
    end if;
    if instr(v_return, 'ϖ') > 0 then
      v_return := replace(v_return, 'ϖ', '\u03D6');
    end if;
    if instr(v_return, 'ϗ') > 0 then
      v_return := replace(v_return, 'ϗ', '\u03D7');
    end if;
    if instr(v_return, 'Ϙ') > 0 then
      v_return := replace(v_return, 'Ϙ', '\u03D8');
    end if;
    if instr(v_return, 'ϙ') > 0 then
      v_return := replace(v_return, 'ϙ', '\u03D9');
    end if;
    if instr(v_return, 'Ϛ') > 0 then
      v_return := replace(v_return, 'Ϛ', '\u03DA');
    end if;
    if instr(v_return, 'ϛ') > 0 then
      v_return := replace(v_return, 'ϛ', '\u03DB');
    end if;
    if instr(v_return, 'Ϝ') > 0 then
      v_return := replace(v_return, 'Ϝ', '\u03DC');
    end if;
    if instr(v_return, 'ϝ') > 0 then
      v_return := replace(v_return, 'ϝ', '\u03DD');
    end if;
    if instr(v_return, 'Ϟ') > 0 then
      v_return := replace(v_return, 'Ϟ', '\u03DE');
    end if;
    if instr(v_return, 'ϟ') > 0 then
      v_return := replace(v_return, 'ϟ', '\u03DF');
    end if;
    if instr(v_return, 'Ϡ') > 0 then
      v_return := replace(v_return, 'Ϡ', '\u03E0');
    end if;
    if instr(v_return, 'ϡ') > 0 then
      v_return := replace(v_return, 'ϡ', '\u03E1');
    end if;
    if instr(v_return, 'Ϣ') > 0 then
      v_return := replace(v_return, 'Ϣ', '\u03E2');
    end if;
    if instr(v_return, 'ϣ') > 0 then
      v_return := replace(v_return, 'ϣ', '\u03E3');
    end if;
    if instr(v_return, 'Ϥ') > 0 then
      v_return := replace(v_return, 'Ϥ', '\u03E4');
    end if;
    if instr(v_return, 'ϥ') > 0 then
      v_return := replace(v_return, 'ϥ', '\u03E5');
    end if;
    if instr(v_return, 'Ϧ') > 0 then
      v_return := replace(v_return, 'Ϧ', '\u03E6');
    end if;
    if instr(v_return, 'ϧ') > 0 then
      v_return := replace(v_return, 'ϧ', '\u03E7');
    end if;
    if instr(v_return, 'Ϩ') > 0 then
      v_return := replace(v_return, 'Ϩ', '\u03E8');
    end if;
    if instr(v_return, 'ϩ') > 0 then
      v_return := replace(v_return, 'ϩ', '\u03E9');
    end if;
    if instr(v_return, 'Ϫ') > 0 then
      v_return := replace(v_return, 'Ϫ', '\u03EA');
    end if;
    if instr(v_return, 'ϫ') > 0 then
      v_return := replace(v_return, 'ϫ', '\u03EB');
    end if;
    if instr(v_return, 'Ϭ') > 0 then
      v_return := replace(v_return, 'Ϭ', '\u03EC');
    end if;
    if instr(v_return, 'ϭ') > 0 then
      v_return := replace(v_return, 'ϭ', '\u03ED');
    end if;
    if instr(v_return, 'Ϯ') > 0 then
      v_return := replace(v_return, 'Ϯ', '\u03EE');
    end if;
    if instr(v_return, 'ϯ') > 0 then
      v_return := replace(v_return, 'ϯ', '\u03EF');
    end if;
    if instr(v_return, 'ϰ') > 0 then
      v_return := replace(v_return, 'ϰ', '\u03F0');
    end if;
    if instr(v_return, 'ϱ') > 0 then
      v_return := replace(v_return, 'ϱ', '\u03F1');
    end if;
    if instr(v_return, 'ϲ') > 0 then
      v_return := replace(v_return, 'ϲ', '\u03F2');
    end if;
    if instr(v_return, 'ϳ') > 0 then
      v_return := replace(v_return, 'ϳ', '\u03F3');
    end if;
    if instr(v_return, 'ϴ') > 0 then
      v_return := replace(v_return, 'ϴ', '\u03F4');
    end if;
    if instr(v_return, 'ϵ') > 0 then
      v_return := replace(v_return, 'ϵ', '\u03F5');
    end if;
    if instr(v_return, '϶') > 0 then
      v_return := replace(v_return, '϶', '\u03F6');
    end if;
    if instr(v_return, 'Ϸ') > 0 then
      v_return := replace(v_return, 'Ϸ', '\u03F7');
    end if;
    if instr(v_return, 'ϸ') > 0 then
      v_return := replace(v_return, 'ϸ', '\u03F8');
    end if;
    if instr(v_return, 'Ϲ') > 0 then
      v_return := replace(v_return, 'Ϲ', '\u03F9');
    end if;
    if instr(v_return, 'Ϻ') > 0 then
      v_return := replace(v_return, 'Ϻ', '\u03FA');
    end if;
    if instr(v_return, 'ϻ') > 0 then
      v_return := replace(v_return, 'ϻ', '\u03FB');
    end if;
    if instr(v_return, 'ϼ') > 0 then
      v_return := replace(v_return, 'ϼ', '\u03FC');
    end if;
    if instr(v_return, 'Ͻ') > 0 then
      v_return := replace(v_return, 'Ͻ', '\u03FD');
    end if;
    if instr(v_return, 'Ͼ') > 0 then
      v_return := replace(v_return, 'Ͼ', '\u03FE');
    end if;
    if instr(v_return, 'Ͽ') > 0 then
      v_return := replace(v_return, 'Ͽ', '\u03FF');
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

