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
