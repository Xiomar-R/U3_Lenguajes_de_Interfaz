# U3 Proyecto: Sistema de ventas (macros, procedimientos y USES)

Sistema de ventas e inventario para la Papelería "El Lápiz", en MASM x86 de 32 bits con Irvine32. Es el proyecto de la Unidad 2 mejorado con macros, procedimientos y USES; conserva las mismas funciones, validaciones y la regla de descuento por cantidad.

**Materia:** Lenguajes de Interfaz · **Docente:** Dr. José Luis Medina Jiménez · **Horario:** 8:00 a 9:00

**Integrantes:**
- Angulo Ramírez Eber Xiomar
- Romero Adrián Juan Ramón
- Urrea Esquerra Héctor Manuel

## Archivos

| Archivo | Contenido |
|---|---|
| `U3_Proyecto_Papeleria.asm` | Código fuente de la Unidad 3 (el que compila el proyecto) |
| `U2_Proyecto_Papeleria.asm` | Versión de la Unidad 2, para comparar antes y después |
| `practica1.vcxproj`, `practica1.vcxproj.filters` | Proyecto de Visual Studio |
| `inventario.txt` | Inventario de prueba con 4 productos |
| `Informe_U3_Papeleria_El_Lapiz.pdf` | Informe con la sección "Versión de la Unidad 3" y la tabla de pruebas |

## Compilación y ejecución

Requisitos: Visual Studio con la carga de trabajo "Desarrollo para el escritorio con C++" y la biblioteca Irvine32 instalada en `C:\Irvine`.

1. Abrir `practica1.vcxproj` con Visual Studio.
2. Seleccionar la configuración **Debug** y la plataforma **x86 (Win32)**.
3. Compilar con **Compilar → Compilar solución** (Ctrl+Shift+B).
4. Ejecutar con **Depurar → Iniciar sin depurar** (Ctrl+F5).

Al iniciar, el programa carga `inventario.txt` de la carpeta del proyecto, que es el directorio de trabajo cuando se ejecuta desde Visual Studio. La opción 7 guarda el catálogo en ese mismo archivo.

## Formato de `inventario.txt`

Una línea por producto, con los campos separados por `|`:

```
CODIGO|NOMBRE|PRECIO_EN_CENTAVOS|EXISTENCIA
CUA-001|Cuaderno profesional|4550|30
```
