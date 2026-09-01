# Declaracion de Uso de Inteligencia Artificial - Parte 1

## Alcance
Esta declaracion documenta cuatro restricciones de integridad incorporadas en `restricciones.sql` para el proyecto Food Store. La consigna pide elegir entre dos y tres reglas; se documentan las cuatro implementadas como trabajo adicional.

## Herramienta
OpenCode, modelo OpenAI `gpt-5.6-terra`.

## Spec o prompt utilizado

### Categoria obligatoria para cada producto
No se conservo el texto exacto del prompt utilizado para esta restriccion. La regla incorporada fue: todo registro de `producto` debe tener un valor no nulo en `id_categoria` y ese valor debe existir en `categoria(id_categoria)`. Esto porque se perdio la conversacion en la que se realizaban esos cambios

### Correo electronico con formato valido basico
No se conservo el texto exacto del prompt utilizado para esta restriccion. La regla incorporada fue: `cliente.correo_electronico` debe incluir una parte local, el caracter `@`, un dominio y una extension, sin espacios. Lo mismo paso en esta ocacion ya que se hicieron sobre la misma conversacion

### Nombre de producto no vacio
Prompt conservado de la conversacion:
> ahora mimso hice 2 restricciones que teniamos, necesito 2 mas, dime algunas restrcciones que no esten en schema.sql ni en restriccione.sql asi vemos cual podemos implementar
> ok, hagamos el 1 y el 2, dime como lo harias

### Nombre y apellido no vacios
Prompt conservado de la conversacion:
> ok perfecto, ahora al editar el archivo quiero que saques el comentario antes del codigo en sql, no pongas RN04 o 05 pone un comentario que diga simplemente la restriccion que estas haciendo por ejemplo --nombre y apellido no vacio

## Que genero la IA

Se trabajo sobre `restricciones.sql` con las siguientes sentencias:
1. `producto.id_categoria` paso a ser obligatorio mediante `ALTER COLUMN id_categoria SET NOT NULL` y se agrego la clave foranea `fk_producto_categoria` hacia `categoria(id_categoria)` con `ON DELETE RESTRICT`.
2. Se agrego `chk_cliente_correo_formato` sobre `cliente.correo_electronico` para validar un formato basico de correo electronico.
3. Se agrego `chk_producto_nombre_no_vacio` sobre `producto.nombre` con `CHECK (btrim(nombre) <> '')`.
4. Se agrego `chk_cliente_nombre_apellido_no_vacios` sobre `cliente.nombre` y `cliente.apellido` con `CHECK (btrim(nombre) <> '' AND btrim(apellido) <> '')`.

## Que se acepto
Se aceptaron las cuatro reglas de integridad y sus nombres de constraints, siguiendo las convenciones del proyecto: `fk_` para claves foraneas y `chk_` para restricciones `CHECK`.
Se acepto `ON DELETE RESTRICT` en la relacion entre `producto` y `categoria` para impedir eliminar una categoria que tenga productos asociados.
Se acepto el uso de `btrim` para que valores vacios o compuestos solamente por espacios sean rechazados sin impedir nombres que tengan espacios al inicio o al final.

## Que se modifico o descarto, y por que
Los comentarios `RN04` y `RN05` fueron reemplazados por comentarios descriptivos simples a pedido del alumno. Los comentarios actuales indican directamente la restriccion que se aplica.
No se inventaron los prompts exactos de las dos primeras reglas porque no se conservaron. Esta ausencia queda registrada para mantener la declaracion fiel al proceso realizado.

## Verificacion realizada
Pendiente de ejecucion en la base de trabajo `foodstore_trabajo`. Todavia no se aplicaron las dos restricciones nuevas en PostgreSQL ni se realizaron los `INSERT` validos e invalidos requeridos por la consigna.

Antes de completar esta seccion se debe:

1. Generar un respaldo real de la base de trabajo con `pg_dump`.
2. Ejecutar las restricciones nuevas dentro de `BEGIN; ... ROLLBACK;`.
3. Probar inserciones validas e invalidas y registrar la salida exacta de PostgreSQL.
4. Repetir la aplicacion con `COMMIT` solo si las pruebas fueron correctas.
