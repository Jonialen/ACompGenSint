# Python Parser - Flex + YACC

Repositorio: [https://github.com/Jonialen/ACompGenSint](https://github.com/Jonialen/ACompGenSint/tree/Yacc)

- `main` — codigo base con el scanner de Flex
- `Yacc` — actividad completa con parser YACC y respuestas

Extends the Python scanner with a YACC grammar that validates syntax and reports
errors with line numbers. Also includes modulo, exponentiation, and list support.

## Files

| File                    | Role                                              |
| ----------------------- | ------------------------------------------------- |
| `python_parser.l`       | Flex lexer - prints tokens and returns codes      |
| `python_parser.y`       | YACC grammar - defines valid syntax               |
| `test_valid.input`      | Valid input (parses cleanly)                      |
| `test_error.input`      | Input with a syntax error on line 2               |
| `test_mod_power.input`  | Test for modulo and exponentiation                |
| `test_lists.input`      | Test for list expressions                         |

## How to Build

```bash
# 1. Enter the container
docker compose up -d --build
docker compose exec flex bash
cd /workspace/examples

# 2. Generate C files
yacc -d python_parser.y    # produces y.tab.c and y.tab.h
flex python_parser.l       # produces lex.yy.c

# 3. Compile
gcc lex.yy.c y.tab.c -o parse
```

## Running

```bash
./parse < test_valid.input
./parse < test_mod_power.input
./parse < test_lists.input
```

## Grammar summary

```
program    -> statement+
statement  -> ID = expr NEWLINE
            | expr NEWLINE
            | def ID ( params ) : NEWLINE
            | NEWLINE
expr       -> expr + term | expr - term | term
term       -> term * power | term / power | term % power | power
power      -> atom ^ power | atom
atom       -> ID | NUMBER | ( expr ) | list
list       -> [ ] | [ expr_list ]
expr_list  -> expr | expr_list , expr
```

## Key YACC variables / functions

| Item           | Description                                             |
| -------------- | ------------------------------------------------------- |
| `yyparse()`    | Starts parsing; returns 0 on success                    |
| `yylex()`      | Called by YACC to get the next token (provided by Flex) |
| `yyerror(msg)` | Called on syntax error; receives the error message      |
| `%token`       | Declares terminal symbols shared between .y and .l      |
| `%left`        | Declares left-associative operators (sets precedence)   |
| `%right`       | Declares right-associative operators                    |
| `yacc -d`      | Generates y.tab.h so the lexer knows the token codes    |

---

# Actividad: Comprendiendo un generador sintactico

## Pregunta 1: Diferencia entre [TOKEN] y [PARSE]

`[TOKEN]` lo imprime el lexer (Flex) cada vez que reconoce un patron en la entrada.
Representa una unidad atomica del lenguaje: un numero, un identificador, un operador.

`[PARSE]` lo imprime el parser (YACC) cada vez que reduce una regla gramatical.
Representa una construccion sintactica completa: una suma, una asignacion, una funcion.

Ejemplo con `y = x + 3`:

```
[TOKEN] ID         -> 'y'      <- lexer reconoce identificador
[TOKEN] ASSIGN     -> '='      <- lexer reconoce operador
[TOKEN] ID         -> 'x'      <- lexer reconoce identificador
[TOKEN] PLUS       -> '+'      <- lexer reconoce operador
[TOKEN] NUMBER     -> '3'      <- lexer reconoce numero
[PARSE] Addition               <- parser reduce: expr PLUS term
[PARSE] Assignment             <- parser reduce: ID ASSIGN expr NEWLINE
```

Los TOKEN siempre aparecen antes de los PARSE porque el parser necesita
consumir tokens para poder aplicar una regla gramatical.

---

## Pregunta 2: Tokens vs reducciones

Los **tokens** son la salida del analisis lexico. El lexer lee caracteres uno a uno
y los agrupa en unidades con significado: `NUMBER`, `ID`, `PLUS`, etc.
No sabe nada de estructura, solo reconoce patrones con expresiones regulares.

Las **reducciones** son la salida del analisis sintactico. El parser toma una
secuencia de tokens o simbolos ya reducidos y los colapsa en un simbolo gramatical
de nivel mas alto. Por ejemplo: `expr PLUS term` se reduce a `expr`.

En resumen:
- Lexer trabaja a nivel de caracteres y patrones.
- Parser trabaja a nivel de estructura gramatical.

---

## Pregunta 3: Como cambiar el formato del output

Para cambiar el formato de `[TOKEN]`, se modifica la funcion `print_token` en
`python_parser.l`. Por ejemplo, para agregar numero de linea:

```c
void print_token(const char* type) {
    printf("  [TOKEN] line=%-3d %-10s -> '%s'\n", line, type, yytext);
}
```

Para cambiar el formato de `[PARSE]`, se modifican los `printf` dentro de
las acciones de cada regla gramatical en `python_parser.y`. Por ejemplo:

```c
expr PLUS term { printf("  [PARSE] line=%-3d Addition\n", line); }
```

Se puede agregar cualquier informacion disponible: numero de linea, valor
del token (`yylval`), nivel de profundidad, etc.

---

## Pregunta 4: Por que ya no es necesario ejecutar ./scanner primero

En la version anterior (solo Flex), el archivo `.l` tenia su propia funcion
`main()` que iniciaba el scanner. El scanner era el programa principal.

Con YACC, el archivo `.y` contiene el `main()`, que llama a `yyparse()`.
`yyparse()` es el parser, y este internamente llama a `yylex()` cada vez que
necesita el siguiente token. `yylex()` es la funcion que genera Flex.

Entonces el flujo cambio:

```
Antes:  main() en .l -> lexer lee y procesa solo
Ahora:  main() en .y -> parser llama al lexer cuando lo necesita
```

El scanner ya no es un programa independiente, es una libreria que el parser
controla. Por eso se compilan juntos con `gcc lex.yy.c y.tab.c -o parse`
y el ejecutable resultante es el parser completo.

---

## Pregunta 5: Agregar modulo (%) y exponenciacion (^)

### Cambios en el scanner (python_parser.l)

Si, es necesario modificar el scanner para que reconozca los nuevos simbolos:

```
"%"   { print_token("MOD");   return MOD;   }
"^"   { print_token("POWER"); return POWER; }
```

Sin esta modificacion, el lexer reportaria un error lexico al encontrar `%` o `^`.

### Cambios en el parser (python_parser.y)

Se declaran los nuevos tokens y su precedencia:

```
%token MOD POWER

%left PLUS MINUS          <- menor precedencia
%left TIMES DIVIDE MOD   <- misma precedencia que * y /
%right POWER              <- mayor precedencia, asociativa a la derecha
```

`%` tiene la misma precedencia que `*` y `/` porque el modulo es una operacion
de la misma familia que la division.

`^` tiene mayor precedencia y es asociativo a la derecha porque `2^3^2`
se interpreta como `2^(3^2) = 512`, no como `(2^3)^2 = 64`.

Se agrega un nivel `power` entre `term` y `atom`:

```
term
    : term TIMES  power   { printf("  [PARSE] Multiplication\n"); }
    | term DIVIDE power   { printf("  [PARSE] Division\n"); }
    | term MOD    power   { printf("  [PARSE] Modulo\n"); }
    | power
    ;

power
    : atom POWER power    { printf("  [PARSE] Exponentiation\n"); }
    | atom
    ;
```

### Caso de prueba: `10 % 3 + 2`

```
[TOKEN] NUMBER -> '10'
[TOKEN] MOD    -> '%'
[TOKEN] NUMBER -> '3'
[TOKEN] PLUS   -> '+'
[PARSE] Modulo             <- se reduce primero por mayor precedencia
[TOKEN] NUMBER -> '2'
[PARSE] Addition           <- luego se reduce la suma
[PARSE] Assignment
```

El resultado es `(10 % 3) + 2 = 1 + 2 = 3`. Correcto.

---

## Pregunta 6: Soporte para listas de expresiones separadas por coma

### Cambios en el scanner (python_parser.l)

Si es necesario agregar los tokens para corchetes:

```
"["  { print_token("LBRACKET"); return LBRACKET; }
"]"  { print_token("RBRACKET"); return RBRACKET; }
```

El token `COMMA` ya existia, no necesita cambios.

### Cambios en el parser (python_parser.y)

Se declaran los nuevos tokens y se agregan las reglas gramaticales:

```
%token LBRACKET RBRACKET

list
    : LBRACKET RBRACKET              { printf("  [PARSE] Empty list\n"); }
    | LBRACKET expr_list RBRACKET    { printf("  [PARSE] List\n"); }
    ;

expr_list
    : expr
    | expr_list COMMA expr
    ;
```

Para que una lista sea valida como expresion, se incluye `list` dentro del
nivel `atom` (el nivel mas bajo de la jerarquia de expresiones):

```
atom
    : ID
    | NUMBER
    | LPAREN expr RPAREN
    | list
    ;
```

Esto permite listas anidadas porque `[2, 3]` es un `atom` que puede aparecer
como elemento dentro de otra lista.

### Casos de prueba

**`empty = []`**
```
[TOKEN] ID       -> 'empty'
[TOKEN] ASSIGN   -> '='
[TOKEN] LBRACKET -> '['
[TOKEN] RBRACKET -> ']'
[PARSE] Empty list
[PARSE] Assignment
```

**`nums = [1, 2, 3]`**
```
[TOKEN] ID       -> 'nums'
[TOKEN] ASSIGN   -> '='
[TOKEN] LBRACKET -> '['
[TOKEN] NUMBER   -> '1'
[TOKEN] COMMA    -> ','
[TOKEN] NUMBER   -> '2'
[TOKEN] COMMA    -> ','
[TOKEN] NUMBER   -> '3'
[TOKEN] RBRACKET -> ']'
[PARSE] List
[PARSE] Assignment
```

**`nested = [1, [2, 3]]`**
```
[TOKEN] ID       -> 'nested'
[TOKEN] ASSIGN   -> '='
[TOKEN] LBRACKET -> '['
[TOKEN] NUMBER   -> '1'
[TOKEN] COMMA    -> ','
[TOKEN] LBRACKET -> '['
[TOKEN] NUMBER   -> '2'
[TOKEN] COMMA    -> ','
[TOKEN] NUMBER   -> '3'
[TOKEN] RBRACKET -> ']'
[PARSE] List               <- se reduce la lista interna primero
[TOKEN] RBRACKET -> ']'
[PARSE] List               <- luego la lista externa
[PARSE] Assignment
```

Los tres casos parsean correctamente sin errores.
