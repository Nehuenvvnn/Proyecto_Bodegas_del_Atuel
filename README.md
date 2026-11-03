# Bodegas del Atuel

Trabajo Practico Integrador de Bases de Datos para construir, desde cero, un sistema de gestion y distribucion de una empresa vitivinicola.

## Objetivo

El centro del sistema es una base PostgreSQL que debe proteger por si misma las reglas de negocio. La API y el front consumiran esa base, pero no calcularan precios, descuentos, totales ni stock.

## Reglas generales del proyecto

- PostgreSQL 14 o superior.
- SQL escrito a mano; no se permite ORM.
- Dinero almacenado con `NUMERIC`, nunca con `FLOAT`.
- Credenciales reales fuera del repositorio.
- Todo cambio debe poder reproducirse desde una base vacia.
- Cada regla de negocio debe tener un mecanismo en la base y una prueba.

## Estado actual

- [x] Paso 0: preparar el repositorio y el PostgreSQL local.
- [ ] Etapa 1: modelado.
- [ ] Etapa 2: integridad y logica en la base.
- [ ] Etapa 3: carga masiva.
- [ ] Etapa 4: indices y rendimiento.
- [ ] Etapa 5: consultas SQL.
- [ ] Etapa 6: API REST.
- [ ] Etapa 7: front.
- [ ] Etapa 8: despliegue en la nube.
- [ ] Etapa 9: documentacion y defensa.

El recorrido completo y los criterios para cerrar cada etapa estan en [docs/plan_de_trabajo.md](docs/plan_de_trabajo.md).

## Primer arranque local

1. Crear la configuracion local, si todavia no existe:

   ```bash
   cp .env.example .env
   ```

2. Levantar PostgreSQL:

   ```bash
   docker compose up -d db
   ```

3. Consultar el estado:

   ```bash
   docker compose ps
   ```

4. Abrir una consola SQL dentro del contenedor:

   ```bash
   docker compose exec db psql -U bodegas_owner -d bodegas_atuel
   ```

5. Detener los contenedores cuando no se usen:

   ```bash
   docker compose down
   ```

`docker compose down` conserva los datos. No agregar `-v` salvo que se quiera borrar deliberadamente el volumen y empezar con una base vacia.

## Carpetas

- `db/`: migraciones, carga de datos y pruebas de la base.
- `consultas/`: ejercicios `INSERT`, `UPDATE`, `DELETE` y `SELECT`.
- `api/`: API REST, a partir de la etapa 6.
- `front/`: interfaz web, a partir de la etapa 7.
- `docs/`: DER, diccionario, decisiones e informes de cada etapa.

