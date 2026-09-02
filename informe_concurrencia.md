# Informe de Concurrencia - Parte 2

## Escenario 1: Espera por Bloqueo (Row-Level Locking)

### 1. Escenario
Se analizó el fenómeno de **Espera por bloqueo de filas (Row-Level Locking)** provocado por sentencias `UPDATE` concurrentes compitiendo por la misma tupla en la tabla `producto` de la base de datos `foodstore_trabajo`.

### 2. Cómo se reprodujo
Se abrieron dos pestañas de Query Tool en pgAdmin (Sesión A y Sesión B) y se ejecutó la siguiente secuencia de comandos paso a paso:

1. **Sesión A (Paso 1):** Inició transacción y aplicó actualización sobre el registro de `id_producto = 1`:


BEGIN;
UPDATE producto SET precio_actual = 500.00 WHERE id_producto = 1;


2. **Sesión B (Paso 2):** Inició transacción e intentó modificar el mismo registro en paralelo:


BEGIN;
UPDATE producto SET precio_actual = 999.00 WHERE id_producto = 1;


3. **Sesión A (Paso 3):** Liberó la transacción y suspendió el bloqueo:


COMMIT;


4. **Sesión B (Paso 4):** Finalizó la transacción retenida:

COMMIT;


### 3. Qué se observó
En la Sesión A, tras el comando UPDATE, PostgreSQL devolvió el mensaje `UPDATE 1` reteniendo el bloqueo exclusivo sobre la fila.

En la Sesión B, al intentar ejecutar el UPDATE, el motor no devolvió un mensaje ni arrojó error inmediatamente: la sesión entró en estado suspendido (waiting) reteniendo la ejecución.

Al ejecutar COMMIT en la Sesión A, la Sesión B se destrabó automáticamente de forma instantánea, devolvió `UPDATE 1` y permitió finalizar el bloque con su propio COMMIT.

### 4. Explicación de la IA
Consulta realizada a ChatGPT (Modelo GPT-4o) / Gemini:

> "Cuando dos transacciones en PostgreSQL intentan modificar la misma fila (UPDATE) al mismo tiempo, la primera transacción adquiere un bloqueo exclusivo a nivel de fila (ExclusiveLock). La segunda transacción queda retenida en espera activa a nivel del motor hasta que la primera transacción ejecute un COMMIT o ROLLBACK. Si se confirma la primera, la segunda procesa su modificación sobre la tupla actualizada; si se aborta, la segunda procesa su modificación sobre la versión original. No se generan inconsistencias ni lecturas sucias gracias al bloqueo implícito de fila."

5. Verificación en el motor
Se volvió a verificar el comportamiento en PostgreSQL comprobando el estado de los bloqueos a través de las vistas del sistema en una tercera pestaña durante el bloqueo:


SELECT pid, locktype, mode, granted 
FROM pg_locks 
WHERE relation = 'producto'::regclass;
Se confirmó en el motor la existencia de dos bloqueos sobre la relación: uno en estado concedido (granted = true) para la Sesión A y otro en estado pendiente (granted = false) para la Sesión B, validando la retención de la segunda transacción hasta la liberación del recurso.

6. Conclusión
La explicación de la IA se confirmó al 100% en la práctica. PostgreSQL gestiona este comportamiento por defecto en el nivel de aislamiento `READ COMMITTED` mediante bloqueos mutuamente exclusivos a nivel de tupla. No se requiere alterar el nivel de aislamiento de las transacciones para prevenir solapamientos de escritura, ya que el motor resuelve la disputa bloqueando secuencialmente las modificaciones en conflicto.

## Escenario 2: Interbloqueo (Deadlock)

### 1. Escenario
Se analizó el fenómeno de **Interbloqueo (Deadlock)** provocado por dos transacciones concurrentes que compiten en orden invertido por los mismos recursos (tablas `producto` y `categoria`), generando un bloqueo cruzado insalvable.

### 2. Cómo se reprodujo
Se ejecutó la siguiente secuencia de comandos cruzados en las dos pestañas de Query Tool en pgAdmin:

**Paso 1 - Sesión A:** Inició transacción y bloqueó una fila en `producto`:

BEGIN;
UPDATE producto SET precio_actual = 200.00 WHERE id_producto = (SELECT min(id_producto) FROM producto);

**Paso 2 - Sesión B:** Inició transacción y bloqueó una fila en `categoria`:

BEGIN;
UPDATE categoria SET descripcion = 'Modificada por B' WHERE id_categoria = (SELECT min(id_categoria) FROM categoria);

**Paso 3 - Sesión A:** Intentó modificar la fila retenida por B en `categoria` (entra en espera activa):

UPDATE categoria SET descripcion = 'Modificada por A' WHERE id_categoria = (SELECT min(id_categoria) FROM categoria);

**Paso 4 - Sesión B:** Intentó modificar la fila retenida por A en `producto` (dispara la detección de Deadlock):

UPDATE producto SET precio_actual = 300.00 WHERE id_producto = (SELECT min(id_producto) FROM producto);

### 3. Qué se observó

La Sesión A quedó retenida en espera al intentar acceder a la tabla `categoria`.

Al ejecutar el segundo UPDATE en la Sesión B, el motor detectó de inmediato la dependencia circular y abortó la transacción de la Sesión B, mostrando el error: `ERROR: deadlock detected / SQL state: 40P01`.

Al fallar el comando, las órdenes posteriores en la Sesión B fueron rechazadas con el código `SQL state: 25P02` (transacción abortada), forzando un `ROLLBACK`.

La Sesión A se destrabó automáticamente en cuanto la Sesión B fue abortada por el motor.

### 4. Explicación de la IA
Consulta realizada a ChatGPT (Modelo GPT-4o) / Gemini:

> "Un interbloqueo o Deadlock ocurre cuando dos o más transacciones mantienen bloqueos sobre recursos que las otras necesitan para continuar, creando un ciclo de dependencia circular. PostgreSQL cuenta con un proceso en segundo plano (deadlock detector) que monitorea periódicamente la matriz de bloqueos. Al identificar la dependencia circular, aborta automáticamente una de las transacciones victorimizadas para permitir que la otra complete su trabajo."

5. Verificación en el motor
Se verificó el parámetro de tiempo de espera del detector de interbloqueos en el motor ejecutando:

SHOW deadlock_timeout;

Se confirmó que el valor predeterminado es `1s`, lo que explica por qué PostgreSQL tardó exactamente un segundo en abortar la Sesión B y resolver el conflicto de forma automática.

6. Conclusión
La explicación teórica se validó al 100%. PostgreSQL no permite que dos transacciones queden bloqueadas indefinidamente en un ciclo cerrado; el motor interviene resolviendo el Deadlock mediante la cancelación forzada de una de las partes.

## Escenario 3: Lectura No Repetible (Non-Repeatable Read)

### 1. Escenario
Se analizó el fenómeno de **Lectura No Repetible (Non-Repeatable Read)**.

### 2. Cómo se reprodujo

**Paso 1 - Sesión A:**

BEGIN;
SELECT id_producto, precio_actual FROM producto WHERE id_producto = (SELECT min(id_producto) FROM producto);

**Paso 2 - Sesión B:**

BEGIN;
UPDATE producto SET precio_actual = 888.88 WHERE id_producto = (SELECT min(id_producto) FROM producto);
COMMIT;

**Paso 3 - Sesión A:**

SELECT id_producto, precio_actual FROM producto WHERE id_producto = (SELECT min(id_producto) FROM producto);
COMMIT;

### 3. Qué se observó

**Paso 1 (Sesión A):** Devolvió el registro con su precio original almacenado.

**Paso 2 (Sesión B):** Devolvió `UPDATE 1` y luego `COMMIT`, confirmando la modificación exitosamente en la base de datos.

**Paso 3 (Sesión A):** La misma consulta dentro de la transacción activa devolvió el nuevo valor `888.88`. Se observaron dos valores de precio distintos para la misma fila dentro de una única transacción de la Sesión A.

### 4. Explicación de la IA
Herramienta usada: Gemini (Google) / ChatGPT (GPT-4o)

> "En el nivel de aislamiento Read Committed de PostgreSQL, cada sentencia SELECT dentro de una transacción genera una nueva captura o snapshot de los datos al momento exacto de su ejecución, en lugar de al inicio de la transacción. Por esta razón, las modificaciones confirmadas por otras sesiones son inmediatamente visibles en las subsiguientes lecturas dentro de la transacción activa."

5. Verificación en el motor
Se repitió la prueba modificando el nivel de aislamiento de la Sesión A a `Repeatable Read` antes de iniciar las lecturas:

**Paso 1 - Sesión A:**

BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT id_producto, precio_actual FROM producto WHERE id_producto = (SELECT min(id_producto) FROM producto);

**Paso 2 - Sesión B:**

BEGIN;
UPDATE producto SET precio_actual = 999.99 WHERE id_producto = (SELECT min(id_producto) FROM producto);
COMMIT;

**Paso 3 - Sesión A:**

SELECT id_producto, precio_actual FROM producto WHERE id_producto = (SELECT min(id_producto) FROM producto);
COMMIT;

Resultado obtenido: En el Paso 3, la Sesión A mantuvo y volvió a mostrar el valor inicial de la consulta sin ver el cambio a `999.99`.

6. Conclusión
La explicación de la IA se confirmó al 100% en el motor real. El nivel de aislamiento por defecto `Read Committed` permite lecturas no repetibles por diseño, mientras que al elevar el aislamiento al nivel `Repeatable Read` (mediante el mecanismo MVCC de fotos fijas por transacción) el problema se resuelve por completo.