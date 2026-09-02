# Ejercicio de Lectura Critica - Parte 3

## Script 1: Baja de funciones retiradas de cartel

### Que filas afectaria realmente
No se dispone de la base de datos ni del esquema generico de cine para enumerar registros concretos. Sin embargo, al no incluir una clausula `WHERE`, el script actualizaria todas las filas de la tabla `funcion`, cambiando el valor de la columna `activa` a `FALSE`.

### Por que no coincide con la consigna
La consigna indica dar de baja unicamente las funciones de peliculas retiradas de cartel. El script no contiene ninguna condicion para identificar cuales funciones fueron retiradas, por lo que tambien desactivaria funciones que todavia estan en cartel.

### Version original
```sql
UPDATE funcion
SET activa = FALSE;
```

### Version corregida
La condicion exacta depende de la columna que el esquema use para registrar el fin de cartelera. Por ejemplo, si `fecha_fin` representa esa fecha:
```sql
UPDATE funcion
SET activa = FALSE
WHERE fecha_fin < CURRENT_DATE
  AND activa = TRUE;
```
La clausula `WHERE` limita la actualizacion a funciones cuya fecha de finalizacion ya paso. La condicion `activa = TRUE` evita actualizar innecesariamente filas que ya estaban dadas de baja.






## Script 2: Eliminacion de categorias sin productos asociados

### Que filas afectaria realmente
El script intenta eliminar las filas de `categoria` cuyo valor de `id_categoria` (usando la base de datos de este proyecto) no aparece en la columna `id_categoria` de la tabla `producto`.

Si la subconsulta devolviera al menos un valor `NULL`, la condicion `NOT IN` no seria verdadera para ninguna categoria. En ese caso, el script podria no eliminar ninguna fila, incluso si existen categorias sin productos asociados.

### Por que no coincide con la consigna
La consigna indica eliminar las categorias que no tienen productos asociados. El uso de `NOT IN` no maneja correctamente los valores `NULL` que podrian existir en la subconsulta. Por esa razon, no garantiza que se eliminen las categorias sin productos.

### Version original
```sql
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto);
```

### Version corregida
```sql
DELETE FROM categoria AS c
WHERE NOT EXISTS (
    SELECT 1
    FROM producto AS p
    WHERE p.id_categoria = c.id_categoria
);
```
La condicion `NOT EXISTS` comprueba, para cada categoria, que no exista ningun producto relacionado. A diferencia de `NOT IN`, esta version funciona correctamente aunque `producto.id_categoria` contenga valores `NULL`.
