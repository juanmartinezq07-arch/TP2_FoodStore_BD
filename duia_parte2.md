# Informe de Concurrencia (Parte 2)

## Escenario 1: Espera por bloqueo (Row-Level Locking)
* **Escenario:** Espera por bloqueo de filas (Row-Level Locking) provocado por sentencias `UPDATE` concurrentes compitiendo por la misma tupla en la tabla `producto`.
* **Cómo se reprodujo:**
  - Sesión A: BEGIN; UPDATE producto SET precio_actual = 500.00 WHERE id_producto = 1;
  - Sesión B: BEGIN; UPDATE producto SET precio_actual = 999.00 WHERE id_producto = 1; (queda suspendida)
  - Sesión A: COMMIT;
  - Sesión B: COMMIT;
* **Qué se observó:** La Sesión B quedó suspendida en espera hasta que la Sesión A ejecutó COMMIT, momento en el que se destrabó automáticamente y devolvió `UPDATE 1`.
* **Explicación de la IA:** La IA explicó que cuando dos transacciones intentan modificar la misma fila, la primera adquiere un bloqueo exclusivo a nivel de fila (`ExclusiveLock`). La segunda queda retenida en espera activa hasta que la primera ejecute `COMMIT` o `ROLLBACK`. No se generan inconsistencias gracias al bloqueo implícito de fila.
* **Verificación en el motor:** Se consultó `pg_locks` y se confirmó un bloqueo concedido (`granted = true`) para la Sesión A y otro pendiente (`granted = false`) para la Sesión B. La liberación fue inmediata al hacer `COMMIT`.
* **Conclusión:** La explicación fue confirmada al 100%. PostgreSQL gestiona este comportamiento por defecto en `READ COMMITTED` mediante bloqueos mutuamente exclusivos a nivel de tupla.

---

## Escenario 2: Interbloqueo real (Deadlock - Error 40P01)
* **Escenario:** Interbloqueo (Deadlock) provocado por dos transacciones concurrentes que compiten en orden invertido por los mismos recursos (tablas `producto` y `categoria`).
* **Cómo se reprodujo:**
  - Sesión A: BEGIN; UPDATE producto SET precio_actual = 200.00 WHERE id_producto = (SELECT min(id_producto) FROM producto);
  - Sesión B: BEGIN; UPDATE categoria SET descripcion = 'Modificada por B' WHERE id_categoria = (SELECT min(id_categoria) FROM categoria);
  - Sesión A: UPDATE categoria SET descripcion = 'Modificada por A' WHERE id_categoria = (SELECT min(id_categoria) FROM categoria); (queda esperando)
  - Sesión B: UPDATE producto SET precio_actual = 300.00 WHERE id_producto = (SELECT min(id_producto) FROM producto); (dispara el detector de deadlock)
* **Qué se observó:** PostgreSQL abortó la transacción de la Sesión B emitiendo el error `ERROR: deadlock detected / SQL state: 40P01`. Las órdenes posteriores fueron rechazadas con `SQL state: 25P02` (transacción abortada), forzando un `ROLLBACK`. La Sesión A se destrabó automáticamente.
* **Explicación de la IA:** Explicó que el deadlock ocurre cuando dos transacciones mantienen bloqueos sobre recursos que las otras necesitan, creando un ciclo de dependencia circular. El detector de interbloqueos de PostgreSQL monitorea la matriz de bloqueos y aborta automáticamente una de las transacciones para resolver el conflicto.
* **Verificación en el motor:** Se ejecutó `SHOW deadlock_timeout;` confirmando el valor predeterminado de `1s` antes de cancelar la transacción.
* **Conclusión:** Se confirmó la predicción de la IA al 100%. PostgreSQL resuelve el deadlock mediante la cancelación forzada de una de las partes.

---

## Escenario 3: Lectura no repetible (Non-Repeatable Read)
* **Escenario:** Lectura no repetible (Non-Repeatable Read) bajo `READ COMMITTED` vs `REPEATABLE READ`.
* **Cómo se reprodujo:**
  - Sesión A: BEGIN; SELECT id_producto, precio_actual FROM producto WHERE id_producto = (SELECT min(id_producto) FROM producto);
  - Sesión B: BEGIN; UPDATE producto SET precio_actual = 888.88 WHERE id_producto = (SELECT min(id_producto) FROM producto); COMMIT;
  - Sesión A: SELECT id_producto, precio_actual FROM producto WHERE id_producto = (SELECT min(id_producto) FROM producto); (devuelve 888.88); COMMIT;
  - Se repitió con `BEGIN ISOLATION LEVEL REPEATABLE READ;` en Sesión A, cambiando el valor a `999.99` en la Sesión B.
* **Qué se observó:** En `READ COMMITTED`, el precio cambió dentro de la misma transacción tras el commit de la Sesión B (dos valores distintos para la misma fila). En `REPEATABLE READ`, el valor se mantuvo inalterado.
* **Explicación de la IA:** Indicó que en `READ COMMITTED` cada `SELECT` genera un nuevo snapshot al momento de su ejecución, mientras que `REPEATABLE READ` utiliza la misma captura desde el inicio de la transacción (MVCC).
* **Verificación en el motor:** Se ejecutó `BEGIN ISOLATION LEVEL REPEATABLE READ;` y se validó que el Paso 3 mostró el valor inicial sin ver el cambio de la Sesión B.
* **Conclusión:** Confirmado al 100%. `READ COMMITTED` permite lecturas no repetibles por diseño; al elevar a `REPEATABLE READ` el problema se resuelve.

---

## Declaración de Uso de IA (DUIA) - Parte 2

* **Herramienta:** OpenCode / IA.
* **Spec o prompt utilizado:** "Explicar e indicar el paso a paso SQL para reproducir 3 escenarios de concurrencia en PostgreSQL (Row-Level Locking, Deadlock y Non-Repeatable Read) sobre las tablas producto y categoria, y redactar los hallazgos en formato de texto plano".
* **Qué generó:** La secuencia de comandos SQL cruzados por pasos para la Sesión A y la Sesión B, las explicaciones teóricas de los bloqueos, error 40P01 y niveles de aislamiento MVCC, además del resumen de conclusiones de cada escenario.
* **Qué se aceptó:** Las secuencias de comandos `BEGIN`, `UPDATE`, `COMMIT`/`ROLLBACK` para reproducir las anomalías, la explicación del parámetro `deadlock_timeout` y la lógica teórica de los niveles de aislamiento.
* **Qué se modificó o descartó, y por qué:** Se ajustaron los nombres de las tablas y campos a nuestro esquema real (`producto` y `categoria` con columnas `id_producto` y `precio_actual`), descartando consultas genéricas con `id` y `precio`. Se adaptaron sentencias de inserción para evitar conflictos con la columna `IDENTITY`.
* **Verificación realizada:** Ejecución paso a paso en dos terminales/sesiones de psql/pgAdmin contra la base de datos de trabajo `foodstore_trabajo`. Confirmación del error `40P01` en vivo y verificación de los aislamientos `READ COMMITTED` y `REPEATABLE READ`.