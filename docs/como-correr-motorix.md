# Cómo correr Motorix tú mismo (y el aviso de build desactualizado)

> **Para:** Kastr
> **Fecha:** 14/10/2026
> **Cuándo leerlo:** cuando llegues a casa y tengas tiempo. No hay apuro.
>
> ---
>
> **Al final de este documento hay una sección para la IA** con el plan de lo que
> hay que implementar. Si lees esto y te convence, diles simplemente:
>
> > *"Ejecuta lo que dijiste en `docs/como-correr-motorix.md`"*
>
> y ellos ya sabrán qué hacer. No tienes que escribir nada más.
>
> ---

---

## PARTE 1 — Cómo correr la app tú mismo

### La idea clave

Son **dos programas** que corren por separado, y necesitas **MySQL encendido** antes.

| Qué | Puerto | Ver en... |
|---|---|---|
| **Backend** (la API, la lógica) | 3000 | terminal |
| **Frontend** (la app que ves) | 8080 | el navegador |
| **MySQL** (la base de datos) | 3306 | — |

### Ahora ya no necesitas escribir comandos

Ya te dejé dos archivos con **doble clic** en la raíz del proyecto:

| Archivo | Qué hace |
|---|---|
| **`arrancar.bat`** | ⭐ Arranca todo solo. |
| **`detener.bat`** | Apaga el backend y el frontend. |

#### Arrancar
1. Abre la carpeta del proyecto.
2. **Doble clic en `arrancar.bat`**.
3. Espera unos segundos. Abre solo:
   - una ventana *BACKEND*
   - una ventana *FRONTEND*
   - tu navegador en **http://localhost:8080**
4. Inicia sesión con `admin` / `Admin2026!`.

#### Detener
- **Cierra las dos ventanas** (BACKEND y FRONTEND), **o**
- **Doble clic en `detener.bat`**.

> MySQL no se toca. Déjalo encendido tranquilo.

#### Otras formas (si prefieres la terminal)
```powershell
.\arrancar.ps1                 # lo mismo que el .bat
.\arrancar.ps1 -SinNavegador   # arranca todo pero sin abrir el navegador
.\arrancar.ps1 -RebuildWeb     # recompila el Flutter web antes
```

> Si te sale un error de "ejecución de scripts deshabilitada", es una política
> de Windows. Solución una sola vez, en PowerShell como administrador:
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
> ```

---

## PARTE 2 — Qué es eso del "build" (explicación sin tecnicismos)

### El frontend tiene DOS versiones dentro de `client`

```
client\
├── lib\          ← Tu CÓDIGO fuente (los archivos .dart que tú editas)
└── build\web\   ← El resultado COMPILADO (lo que el navegador entiende)
```

### La analogía del chef 🧑‍🍳

- **`lib\`** son las **recetas**: ingredientes, instrucciones, texto. Bonito,
  legible, pero **no se puede comer directo**.
- **`build\web\`** es la **comida ya hecha**, emplatada y lista para servir.

Para pasar de receta a plato hecho hay que **cocinar**. En Flutter ese "cocinar"
se llama **compilar**, y el comando es `flutter build web`. Lo que sale de cocinar
se guarda en `build\web\`.

### ¿Y quién come? El navegador 🌐

Cuando abres **http://localhost:8080**, tu servidor web **no lee `lib\`**. Lee
directamente **`build\web\`**. Es decir: le sirve al navegador **la comida ya
hecha**, la que estaba en la cocina al momento de emplatar.

---

### ¿Cuál es el problema?

Si tú abres `lib\main.dart` y cambias un texto, agregas una pantalla o corriges
un botón... **tu código cambió, pero el plato de la cocina sigue siendo el viejo**.

El navegador **no se entera** de tu cambio. Sigue viendo el build viejo. Y tú te
preguntas:

> "¿Por qué no se me aplica mi cambio? ¿Está roto?"

**No está roto.** Simplemente nadie volvió a cocinar. Tu cambio está guardado en
la receta, pero nunca se emplató.

### ¿Cómo lo comprobamos? Con las fechas

Esto es lo que tenía tu proyecto cuando escribí esto:

| Archivo | Última vez que se guardó |
|---|---|
| `lib\main.dart` (tu código) | 14/10/2026 **08:11** |
| `build\web\index.html` (el plato) | 14/10/2026 **10:44** |

La comida se hizo a las **10:44** y la receta se tocó por última vez a las
**08:11**. Como el plato es **más nuevo** que la receta → **todo bien, estás
viendo lo último**.

⚠️ Pero si algún día editas `main.dart` a las **12:00**, la receta queda más nueva
que el plato. Ahí ya estarías viendo algo **desactualizado**.

---

### Por qué el script "no recompila Flutter"

`arrancar.bat` lo único que hace es **servir el plato que ya está en la cocina**.
No cocina.

¿Por qué? Porque **compilar Flutter es lento**: depende de tu máquina, puede tardar
desde 20 segundos hasta varios minutos. Si cada vez que quieres *ver* la app
tuvieras que esperar ese rato, se volvería molesto.

Entonces el script asume:

> "Si el usuario quiere ver la app, quiere verla **ya**. Yo sirvo lo que hay."

Y por eso te dejé la otra opción aparte, para cuando **sí** quieras cocinar:

```powershell
.\arrancar.ps1 -RebuildWeb
```

Eso le dice: **"primero cocina otra vez, y luego sirve"**. Eso es todo. El
`-RebuildWeb` es un interruptor que enciende ese paso extra.

#### Resumen en una frase

| Comando | Qué hace |
|---|---|
| `.\arrancar.bat` | Sirve lo que ya está cocinado. **Rápido.** |
| `.\arrancar.ps1 -RebuildWeb` | **Cocina de cero** y luego sirve. **Lento pero al día.** |

---

### La idea del aviso automático (PARTA 3 de la implementación)

El problema real es de **cerebro humano**:

> Cambias el código → dobles clic en `arrancar.bat` → ves la app → **no ves tu
> cambio** → te frustras → dices "esto está roto" → pasas media hora buscando un
> bug que no existe.

A eso se le llama un **build desactualizado** (*stale* en inglés). Es una de las
formas más comunes de hacerse perder el tiempo.

#### ¿Cómo se arregla? Comparando fechas

**Comparar la fecha de `lib\` contra la de `build\web\`**:

- Si el código de `lib\` es **más viejo** que el build → todo bien, sirve normal.
- Si el código de `lib\` es **más nuevo** → **¡cuidado!**, avisa.

#### Cómo se vería en la práctica

Le dobles clic al `.bat` y te aparece:

```
  [OK] Node.js v24.19.0
  [OK] MySQL ya esta corriendo.

  ¡ATENCION! Tu codigo cambio despues del ultimo build.
      Codigo editado por ultima vez:  14/10 12:00
      Build (lo que se va a mostrar): 14/10 10:44

  El navegador te mostrara una version VIEJA de la app.

  ¿Quieres recompilar ahora? (S/N):
```

- Presionas **`S`** → cocina de cero y sirve lo nuevo. ✅
- Presionas **`N`** → sirve igual la versión vieja (por si estás probando algo y
  no quieres esperar).

Y si no tocaste nada, ni se molesta en preguntar:

```
  [OK] Build al dia.
```

---

### En resumen, las dos cosas

1. **El script sirve, no cocina.** Sirve el `build\web` que ya existe. Si tocas
   código, ese build queda viejo y hay que recompilar con `flutter build web`
   (o con `-RebuildWeb`).

2. **El aviso automático** es simplemente que el script **compare fechas** antes de
   servir, y te diga "ojo, esto que vas a ver no refleja tus últimos cambios".
   Evita que pierdas tiempo creyendo que algo está roto cuando en realidad solo
   falta compilar.

---
---

# 📋 PARTE 3 — PARA LA IA: plan de implementación

> **Esto no es para ti, Kastr.** Es la instrucción técnica para quien lea esto
> después. Kastr: si la PARTE 2 te convenció, diles simplemente
> *"Ejecuta lo que dijiste en `docs/como-correr-motorix.md`"*.

## Objetivo

Que `arrancar.bat` / `arrancar.ps1` detecte automáticamente si el build de Flutter
web quedó desactualizado respecto al código fuente en `client\lib\`, y avise al
usuario antes de servir.

## Archivos a tocar

- `arrancar.ps1` (raíz del proyecto) → agregar la detección.
- `scripts/web-server.cjs` → **no se toca**.

## Lógica a implementar

### 1. Calcular las fechas

- **Fecha del código**: la fecha de modificación **más reciente** de todo archivo
  `.dart` dentro de `client\lib\` (recursivo).
- **Fecha del build**: leer `client\build\web\.last_build_id` si existe; si no,
  usar la fecha del archivo `client\build\web\index.html`.

### 2. Comparar

- Si `fechaCodigo <= fechaBuild` → **build al día**. Imprimir
  `[OK] Build al dia.` y continuar sin interrumpir (comportamiento actual).
- Si `fechaCodigo > fechaBuild` → **build desactualizado**. Continuar con el aviso.

### 3. Aviso y pregunta

Cuando esté desactualizado, imprimir:

```
  ¡ATENCION! Tu codigo cambio despues del ultimo build.
      Codigo editado por ultima vez:  <fechaCodigo>
      Build (lo que se va a mostrar): <fechaBuild>

  El navegador te mostrara una version VIEJA de la app.
```

Luego preguntar con `Read-Host "  ¿Quieres recompilar ahora? (S/N)"`:

- **`S` / `s` / `Si` / `si`** → ejecutar el mismo bloque de `-RebuildWeb`
  (`flutter build web` dentro de `client\`), luego continuar.
- **`N` / cualquier otra cosa** → continuar sirviendo el build viejo.

### 4. Consideraciones importantes

- **La pregunta NO debe aparecer** cuando se lance con `-RebuildWeb` (ya se está
  recompilando) ni con `-SinNavegador` en modo no interactivo. En ese caso, si hay
  `-RebuildWeb` se omite la pregunta por completo.
- Falta un interruptor **`-SinPreguntar`** (o `-Yes`) que omita la pregunta y
  asuma "no recompilar", para uso no interactivo/automatizado.
- Si `client\lib\` no tiene archivos `.dart`, o no existe el build, mantener el
  comportamiento de error actual.
- Si no se encuentra `flutter` en el PATH, avisar en lugar de fallar en silencio.
- Todos los mensajes **en español**, identificadores del código **en inglés**
  (regla del proyecto, ver `AGENTS.md`).

## Criterios de aceptación

- [ ] Si `lib\` no cambió desde el último build, `arrancar.bat` se comporta igual
      que hoy (sin preguntas).
- [ ] Si `lib\` cambió, aparece el aviso con ambas fechas y pregunta S/N.
- [ ] Responder `S` recompila y luego arranca normalmente.
- [ ] Responder `N` arranca igual, sirviendo el build viejo.
- [ ] Con `-RebuildWeb` nunca aparece la pregunta (ya recompila).
- [ ] Con el nuevo `-SinPreguntar` nunca aparece la pregunta.
- [ ] Los mensajes están en español con tildes correctas.

## Nota sobre convenciones

Seguir `AGENTS.md`: comentarios y mensajes al usuario en español, identificadores
de código en inglés, sin secretos en el repositorio.
