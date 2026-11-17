; Materia: Lenguajes de Interfaz
; Alumno: Eber Angulo Ramirez
; Horario: 8 a 9
; Docente: Dr. José Luis Medina Jiménez
; Proyecto: Unidad 3. Sistema de ventas e inventario (macros, procedimientos y USES)
; Negocio: Papelería "El Lápiz"


INCLUDE Irvine32.inc

MAX_PROD   = 10          ; capacidad del catálogo
TAM_COD    = 8           ; bytes del código con su 00h
TAM_NOM    = 26          ; bytes del nombre con su 00h
OFS_COD    = 0           ; desplazamientos dentro de un producto
OFS_NOM    = 8
OFS_PRE    = 36
OFS_EXI    = 40
TAM_PROD   = 44          ; tamaño de un producto
MAX_PRECIO = 999999      ; $9999.99 en centavos
MAX_EXIST  = 100
DESC_MIN   = 10          ; piezas mínimas para el descuento
TAM_ARCH   = 1024        ; capacidad del buffer del archivo

;========================= MACROS =========================

; mLinea: muestra un mensaje y salto de línea. Modifica EDX.
mLinea MACRO mensaje
    mov edx, OFFSET mensaje
    call MostrarLinea
ENDM

; mCaracter: muestra un carácter. Modifica AL.
mCaracter MACRO car
    mov al, car
    call WriteChar
ENDM

; mCapturar: muestra un mensaje y lee una línea. Regresa ESI = entrada, ECX = EAX = largo.
mCapturar MACRO mensaje
    mov edx, OFFSET mensaje
    call LeerEntrada
    mov esi, OFFSET entrada
    mov ecx, eax
ENDM

; mRango: CF = 0 si minimo <= valor <= maximo, CF = 1 si no. Etiquetas LOCAL.
mRango MACRO valor, minimo, maximo
    LOCAL fuera, listo
    cmp valor, minimo
    jb fuera
    cmp valor, maximo
    ja fuera
    clc
    jmp listo
fuera:
    stc
listo:
ENDM

; mOpcion: si AL = tecla, llama al procedimiento y regresa al menú. Etiqueta LOCAL.
mOpcion MACRO tecla, procedimiento
    LOCAL otra
    cmp al, tecla
    jne otra
    call procedimiento
    jmp menuPrincipal
otra:
ENDM

.data
    catalogo     BYTE MAX_PROD * TAM_PROD DUP(0)
    numProd      DWORD 0                 ; productos registrados
    ingresos     DWORD 0                 ; ingresos de la sesión en centavos
    cambios      BYTE 0                  ; 1 = hay cambios sin guardar

    catTemp      BYTE MAX_PROD * TAM_PROD DUP(0) ; para validar el archivo
    numTemp      DWORD 0

    entrada      BYTE 41 DUP(0)
    numBuffer    BYTE 12 DUP(0)

    nombreArchivo BYTE "inventario.txt", 0
    archivoHandle DWORD 0
    bufArchivo   BYTE TAM_ARCH + 1 DUP(0) ; +1 para el 00h
    bytesLeidos  DWORD 0
    lineaBuf     BYTE 64 DUP(0)

    titulo       BYTE "===== PAPELERIA EL LAPIZ - VENTAS E INVENTARIO =====", 0
    txtMenu      BYTE "1. Registrar producto", 0Dh, 0Ah
                 BYTE "2. Mostrar inventario", 0Dh, 0Ah
                 BYTE "3. Buscar producto por codigo", 0Dh, 0Ah
                 BYTE "4. Recibir mercancia", 0Dh, 0Ah
                 BYTE "5. Vender", 0Dh, 0Ah
                 BYTE "6. Mostrar resumen", 0Dh, 0Ah
                 BYTE "7. Guardar catalogo", 0Dh, 0Ah
                 BYTE "8. Cargar catalogo", 0Dh, 0Ah
                 BYTE "9. Salir", 0Dh, 0Ah, 0
    msgOpcion    BYTE "Elige una opcion: ", 0
    msgOpcionMal BYTE "Opcion no valida.", 0

    msgPideCodigo BYTE "Codigo (ABC-123): ", 0
    msgCodigoMal BYTE "Codigo incorrecto: 3 letras mayusculas, guion y 3 digitos.", 0
    msgDuplicado BYTE "Ya existe un producto con ese codigo. Registro rechazado.", 0
    msgLleno     BYTE "El catalogo esta lleno (10 productos). Registro rechazado.", 0
    msgPideNombre BYTE "Nombre (1 a 25 caracteres): ", 0
    msgNombreMal BYTE "Nombre invalido: de 1 a 25 caracteres y sin el caracter |.", 0
    msgPidePrecio BYTE "Precio en MXN (ej. 185.50): ", 0
    msgPrecioMal BYTE "Precio invalido: solo digitos y punto con 1 o 2 decimales, de 0.01 a 9999.99.", 0
    msgPideExist BYTE "Existencia inicial (0 a 100): ", 0
    msgExistMal  BYTE "Existencia invalida: entero de 0 a 100.", 0
    msgRegistrado BYTE "Producto registrado.", 0

    msgEncabezado BYTE "CODIGO   NOMBRE                      PRECIO          EXIST", 0
    msgVacio     BYTE "No hay productos registrados.", 0
    msgNoExiste  BYTE "No existe un producto con ese codigo.", 0
    msgPideCant  BYTE "Cantidad (entero mayor que 0): ", 0
    msgCantMal   BYTE "Cantidad invalida: escribe un entero mayor que 0.", 0
    msgExcede    BYTE "Entrada rechazada: la existencia no puede pasar de 100 unidades.", 0
    msgEntradaOk BYTE "Mercancia recibida. Nueva existencia: ", 0

    msgSinExist  BYTE "Venta rechazada: no hay existencias suficientes.", 0
    msgDesborde  BYTE "Operacion rechazada: el resultado desborda 32 bits.", 0
    msgImporte   BYTE "Importe base:  ", 0
    msgDescuento BYTE "Descuento 10% por 10 o mas piezas: -", 0
    msgSinDesc   BYTE "Sin descuento (aplica desde 10 piezas).", 0
    msgTotal     BYTE "Total a pagar: ", 0
    msgVentaOk   BYTE "Venta registrada. Existencia restante: ", 0

    msgResTit    BYTE "----------- RESUMEN -----------", 0
    msgResProd   BYTE "Productos registrados: ", 0
    msgResUnid   BYTE "Unidades disponibles:  ", 0
    msgResValor  BYTE "Valor del inventario:  ", 0
    msgResIngr   BYTE "Ingresos de la sesion: ", 0

    msgGuardado  BYTE "Catalogo guardado en inventario.txt", 0
    msgErrCrear  BYTE "Error: no se pudo crear el archivo.", 0
    msgErrEscribir BYTE "Error: no se escribieron todos los bytes.", 0
    msgCargado   BYTE "Catalogo cargado desde inventario.txt. Productos: ", 0
    msgNoArchivo BYTE "No se encontro inventario.txt. Se conserva el catalogo actual.", 0
    msgArchMal   BYTE "Archivo invalido o danado. Se conserva el catalogo actual.", 0

    msgSalir     BYTE "Hay cambios sin guardar. Salir de todos modos? (S/N): ", 0
    msgAdios     BYTE "Hasta luego.", 0
    txtMXN       BYTE " MXN", 0
    txtSep       BYTE "  ", 0

.code
main PROC
    mLinea titulo
    call CargarArchivo

menuPrincipal:
    call Crlf
    mov edx, OFFSET txtMenu
    call WriteString
    mov edx, OFFSET msgOpcion
    call LeerEntrada
    cmp eax, 1                   ; la opción es de un solo carácter
    jne opcionMala
    mov al, entrada
    mOpcion '1', RegistrarProducto
    mOpcion '2', MostrarInventario
    mOpcion '3', BuscarProducto
    mOpcion '4', RecibirMercancia
    mOpcion '5', Vender
    mOpcion '6', MostrarResumen
    mOpcion '7', GuardarArchivo
    mOpcion '8', CargarArchivo
    cmp al, '9'
    je op9
opcionMala:
    mLinea msgOpcionMal
    jmp menuPrincipal

op9:
    cmp cambios, 0               ; si hay cambios sin guardar, pregunto
    je salir
    mov edx, OFFSET msgSalir
    call LeerEntrada
    mov al, entrada
    cmp al, 'S'
    je salir
    cmp al, 's'
    je salir
    jmp menuPrincipal

salir:
    mLinea msgAdios
    exit
main ENDP

;================== ENTRADA Y SALIDA ==================

MostrarLinea PROC
    call WriteString
    call Crlf
    ret
MostrarLinea ENDP

; LeerEntrada: recibe EDX = mensaje; regresa EAX = caracteres leídos en entrada.
LeerEntrada PROC USES ecx edx
    call WriteString
    mov edx, OFFSET entrada
    mov ecx, SIZEOF entrada - 1  ; dejo lugar al 00h
    call ReadString
    ret
LeerEntrada ENDP

; EnteroACadena: recibe EAX = valor, EDI = buffer; deja la cadena con 00h.
EnteroACadena PROC USES eax ebx ecx edx edi
    mov ebx, 10
    mov ecx, 0                   ; ECX cuenta los dígitos
ecDividir:
    mov edx, 0
    div ebx                      ; EAX = cociente, EDX = residuo
    add dl, '0'                  ; residuo a ASCII
    push edx                     ; salen al revés, los guardo en la pila
    inc ecx
    cmp eax, 0
    jne ecDividir
ecSacar:
    pop edx
    mov [edi], dl
    inc edi
    loop ecSacar
    mov BYTE PTR [edi], 0
    ret
EnteroACadena ENDP

; MostrarNumero: recibe EAX = valor y lo muestra.
MostrarNumero PROC USES edx edi
    mov edi, OFFSET numBuffer
    call EnteroACadena
    mov edx, OFFSET numBuffer
    call WriteString
    ret
MostrarNumero ENDP

; MostrarMXN: recibe EAX = centavos y muestra $1234.05 MXN.
MostrarMXN PROC USES eax ebx edx
    mov edx, 0
    mov ebx, 100
    div ebx                      ; EAX = pesos, EDX = centavos
    mov ebx, eax
    mCaracter '$'
    mov eax, ebx
    call MostrarNumero
    mCaracter '.'
    mov eax, edx
    cmp eax, 10                  ; 5 se muestra como 05
    jae mmCentavos
    push eax
    mCaracter '0'
    pop eax
mmCentavos:
    call MostrarNumero
    mov edx, OFFSET txtMXN
    call WriteString
    ret
MostrarMXN ENDP

; MostrarDato (nuevo): recibe EDX = mensaje, EAX = número; muestra ambos y salto de línea.
MostrarDato PROC
    call WriteString
    call MostrarNumero
    call Crlf
    ret
MostrarDato ENDP

; MostrarImporte (nuevo): recibe EDX = mensaje, EAX = centavos; muestra ambos y salto de línea.
MostrarImporte PROC
    call WriteString
    call MostrarMXN
    call Crlf
    ret
MostrarImporte ENDP

;================ VALIDACIÓN Y CONVERSIÓN ================

; ValidarCodigo: recibe ESI = cadena, ECX = largo; CF = 0 si es ABC-123.
ValidarCodigo PROC USES eax ecx esi
    cmp ecx, 7
    jne vcError
    mov ecx, 3
vcLetras:
    mov al, [esi]
    mRango al, 'A', 'Z'
    jc vcError
    inc esi
    loop vcLetras
    cmp BYTE PTR [esi], '-'
    jne vcError
    inc esi
    mov ecx, 3
vcDigitos:
    mov al, [esi]
    mRango al, '0', '9'
    jc vcError
    inc esi
    loop vcDigitos
    clc
    jmp vcFin
vcError:
    stc
vcFin:
    ret
ValidarCodigo ENDP

; ConvertirEntero: recibe ESI = cadena, ECX = largo; regresa EAX = valor, CF = 1 si es inválido.
ConvertirEntero PROC USES ecx edx esi
    cmp ecx, 0
    je ceError
    cmp ecx, 9                   ; más de 9 dígitos puede desbordar
    ja ceError
    mov eax, 0
ceCiclo:
    movzx edx, BYTE PTR [esi]
    mRango dl, '0', '9'
    jc ceError
    sub dl, '0'
    imul eax, eax, 10            ; valor = valor * 10 + dígito
    jo ceError
    add eax, edx
    jc ceError
    inc esi
    loop ceCiclo
    clc
    jmp ceFin
ceError:
    stc
ceFin:
    ret
ConvertirEntero ENDP

; ConvertirPrecio: recibe ESI = cadena, ECX = largo; regresa EAX = centavos, CF = 1 si es inválido.
ConvertirPrecio PROC USES ebx ecx edx esi
    mov edx, ecx                 ; EDX = largo total
    mov ecx, 0                   ; ECX = caracteres antes del punto
cpBuscaPunto:
    cmp ecx, edx
    je cpPesos
    cmp BYTE PTR [esi+ecx], '.'
    je cpPesos
    inc ecx
    jmp cpBuscaPunto

cpPesos:
    cmp ecx, 4
    ja cpError
    call ConvertirEntero         ; EAX = pesos
    jc cpError
    imul ebx, eax, 100           ; EBX = pesos en centavos
    sub edx, ecx                 ; EDX = punto + decimales
    cmp edx, 0
    je cpRango

    add esi, ecx
    inc esi                      ; ESI = primer decimal
    mov ecx, edx
    dec ecx                      ; ECX = cantidad de decimales
    cmp ecx, 2
    ja cpError
    call ConvertirEntero         ; EAX = decimales
    jc cpError
    cmp ecx, 2
    je cpSumar
    imul eax, eax, 10            ; un decimal: .5 = 50 centavos
cpSumar:
    add ebx, eax

cpRango:
    mov eax, ebx
    mRango eax, 1, MAX_PRECIO
    jmp cpFin
cpError:
    stc
cpFin:
    ret
ConvertirPrecio ENDP

;======================= BÚSQUEDA =======================

; BuscarEnCatalogo: recibe EDX = código, ESI = catálogo, ECX = productos; regresa ESI = producto, CF = 1 si no existe.
BuscarEnCatalogo PROC USES eax ebx ecx
    cmp ecx, 0
    je bcNoEsta
bcSiguiente:
    mov ebx, 0
bcComparar:
    mov al, [edx+ebx]
    cmp al, [esi+ebx+OFS_COD]
    jne bcOtro
    inc ebx
    cmp ebx, 7
    jb bcComparar
    clc
    jmp bcFin
bcOtro:
    add esi, TAM_PROD            ; siguiente producto
    loop bcSiguiente
bcNoEsta:
    stc
bcFin:
    ret
BuscarEnCatalogo ENDP

; BuscarCodigo: recibe EDX = código; regresa ESI = producto, CF = 1 si no existe.
BuscarCodigo PROC USES ecx
    mov esi, OFFSET catalogo
    mov ecx, numProd
    call BuscarEnCatalogo
    ret
BuscarCodigo ENDP

; PedirCodigo: pide un código hasta que sea válido; queda en entrada.
PedirCodigo PROC USES eax ecx edx esi
pcoPedir:
    mCapturar msgPideCodigo
    call ValidarCodigo
    jnc pcoFin
    mLinea msgCodigoMal
    jmp pcoPedir
pcoFin:
    ret
PedirCodigo ENDP

; PedirProducto: pide un código; regresa ESI = producto, CF = 1 si no existe.
PedirProducto PROC USES edx
    call PedirCodigo
    mov edx, OFFSET entrada
    call BuscarCodigo
    jnc ppFin
    mLinea msgNoExiste
    stc
ppFin:
    ret
PedirProducto ENDP

; PedirCantidad: pide un entero mayor que 0; regresa EAX = cantidad.
PedirCantidad PROC USES ecx edx esi
pcaPedir:
    mCapturar msgPideCant
    call ConvertirEntero
    jc pcaMal
    cmp eax, 1
    jae pcaFin
pcaMal:
    mLinea msgCantMal
    jmp pcaPedir
pcaFin:
    ret
PedirCantidad ENDP

; CalcularImporte (nuevo): recibe EAX = precio, ECX = piezas; regresa EAX = importe,
; EDX = descuento del 10% desde 10 piezas (0 si no aplica), CF = 1 si desborda.
CalcularImporte PROC USES edi
    mul ecx                      ; EDX:EAX = precio * piezas
    jc ciFin
    mov edx, 0
    cmp ecx, DESC_MIN
    jb ciListo
    push eax
    mov edi, 10
    div edi                      ; EAX = 10%, se descarta el residuo
    mov edx, eax
    pop eax
ciListo:
    clc
ciFin:
    ret
CalcularImporte ENDP

;==================== FUNCIONES DEL MENÚ ====================

; RegistrarProducto (opción 1): numProd solo aumenta cuando todo es válido.
RegistrarProducto PROC USES eax ebx ecx edx esi edi
    cld
    cmp numProd, MAX_PROD
    jb rpCodigo
    mLinea msgLleno
    jmp rpFin

rpCodigo:
    call PedirCodigo
    mov edx, OFFSET entrada
    call BuscarCodigo            ; CF = 0: ya existe
    jc rpNuevo
    mLinea msgDuplicado
    jmp rpFin
rpNuevo:
    mov eax, numProd             ; EBX = catalogo + numProd * 44
    imul ebx, eax, TAM_PROD
    add ebx, OFFSET catalogo
    mov esi, OFFSET entrada
    lea edi, [ebx+OFS_COD]
    mov ecx, TAM_COD
    rep movsb

rpNombre:
    mCapturar msgPideNombre
    mRango ecx, 1, 25
    jc rpNombreMal
rpRevisa:
    cmp BYTE PTR [esi], '|'      ; | es el separador del archivo
    je rpNombreMal
    inc esi
    loop rpRevisa
    mov esi, OFFSET entrada
    lea edi, [ebx+OFS_NOM]
    mov ecx, eax
    inc ecx
    rep movsb
    jmp rpPrecio
rpNombreMal:
    mLinea msgNombreMal
    jmp rpNombre

rpPrecio:
    mCapturar msgPidePrecio
    call ConvertirPrecio
    jnc rpPrecioOk
    mLinea msgPrecioMal
    jmp rpPrecio
rpPrecioOk:
    mov [ebx+OFS_PRE], eax

rpExist:
    mCapturar msgPideExist
    call ConvertirEntero
    jc rpExistMal
    cmp eax, MAX_EXIST
    jbe rpGuardar
rpExistMal:
    mLinea msgExistMal
    jmp rpExist

rpGuardar:
    mov [ebx+OFS_EXI], eax
    inc numProd
    mov cambios, 1
    mLinea msgRegistrado
rpFin:
    ret
RegistrarProducto ENDP

; MostrarProducto: recibe ESI = producto y lo muestra en una línea.
MostrarProducto PROC USES eax ecx edx
    lea edx, [esi+OFS_COD]
    call WriteString
    mov edx, OFFSET txtSep
    call WriteString
    lea edx, [esi+OFS_NOM]
    call WriteString
    call StrLength
    mov ecx, 28
    sub ecx, eax                 ; espacios para alinear
mpRelleno:
    mCaracter ' '
    loop mpRelleno
    mov eax, [esi+OFS_PRE]
    call MostrarMXN
    mov edx, OFFSET txtSep
    call WriteString
    mov eax, [esi+OFS_EXI]
    call MostrarNumero
    call Crlf
    ret
MostrarProducto ENDP

; MostrarInventario (opción 2): recorre el catálogo con ESI.
MostrarInventario PROC USES ecx edx esi
    mov ecx, numProd
    cmp ecx, 0
    jne miHay
    mLinea msgVacio
    jmp miFin
miHay:
    mLinea msgEncabezado
    mov esi, OFFSET catalogo
miCiclo:
    call MostrarProducto
    add esi, TAM_PROD
    loop miCiclo
miFin:
    ret
MostrarInventario ENDP

; BuscarProducto (opción 3)
BuscarProducto PROC USES edx esi
    call PedirProducto
    jc bpFin
    mLinea msgEncabezado
    call MostrarProducto
bpFin:
    ret
BuscarProducto ENDP

; RecibirMercancia (opción 4): suma unidades sin pasar de 100.
RecibirMercancia PROC USES eax ebx edx esi
    call PedirProducto
    jc rmFin
    call PedirCantidad
    mov ebx, [esi+OFS_EXI]
    add ebx, eax
    cmp ebx, MAX_EXIST
    ja rmExcede
    mov [esi+OFS_EXI], ebx
    mov cambios, 1
    mov edx, OFFSET msgEntradaOk
    mov eax, ebx
    call MostrarDato
    jmp rmFin
rmExcede:
    mLinea msgExcede
rmFin:
    ret
RecibirMercancia ENDP

; Vender (opción 5): existencia e ingresos cambian solo si todo es válido.
Vender PROC USES eax ebx ecx edx esi edi
    call PedirProducto
    jc veFin
    call PedirCantidad
    mov ecx, eax                 ; ECX = piezas
    cmp ecx, [esi+OFS_EXI]
    ja veSinExist

    mov eax, [esi+OFS_PRE]
    call CalcularImporte         ; EAX = importe, EDX = descuento
    jc veDesborde
    mov ebx, eax
    mov edi, edx
    mov edx, OFFSET msgImporte
    call MostrarImporte

    cmp edi, 0                   ; 0 = no aplica la regla
    je veSinDesc
    mov edx, OFFSET msgDescuento
    mov eax, edi
    call MostrarImporte
    sub ebx, edi                 ; EBX = importe final
    jmp veTotal
veSinDesc:
    mLinea msgSinDesc

veTotal:
    mov eax, ingresos
    add eax, ebx
    jc veDesborde
    mov edx, OFFSET msgTotal
    push eax
    mov eax, ebx
    call MostrarImporte
    pop eax
    mov ingresos, eax            ; ahora sí actualizo
    sub [esi+OFS_EXI], ecx
    mov cambios, 1
    mov edx, OFFSET msgVentaOk
    mov eax, [esi+OFS_EXI]
    call MostrarDato
    jmp veFin

veSinExist:
    mLinea msgSinExist
    jmp veFin
veDesborde:
    mLinea msgDesborde
veFin:
    ret
Vender ENDP

; MostrarResumen (opción 6): unidades, valor del inventario e ingresos.
MostrarResumen PROC USES eax ebx ecx edx esi edi
    mov esi, OFFSET catalogo
    mov ecx, numProd
    mov ebx, 0                   ; EBX = unidades
    mov edi, 0                   ; EDI = valor del inventario
    cmp ecx, 0
    je mrMostrar
mrCiclo:
    add ebx, [esi+OFS_EXI]
    mov eax, [esi+OFS_PRE]
    mul DWORD PTR [esi+OFS_EXI]
    jc mrDesborde
    add edi, eax
    jc mrDesborde
    add esi, TAM_PROD
    loop mrCiclo

mrMostrar:
    mLinea msgResTit
    mov edx, OFFSET msgResProd
    mov eax, numProd
    call MostrarDato
    mov edx, OFFSET msgResUnid
    mov eax, ebx
    call MostrarDato
    mov edx, OFFSET msgResValor
    mov eax, edi
    call MostrarImporte
    mov edx, OFFSET msgResIngr
    mov eax, ingresos
    call MostrarImporte
    jmp mrFin
mrDesborde:
    mLinea msgDesborde
mrFin:
    ret
MostrarResumen ENDP

;======================= ARCHIVOS =======================

; CopiarCadena: copia ESI a EDI sin el 00h; regresa EDI = siguiente posición.
CopiarCadena PROC USES eax esi
ccCiclo:
    mov al, [esi]
    cmp al, 0
    je ccFin
    mov [edi], al
    inc esi
    inc edi
    jmp ccCiclo
ccFin:
    ret
CopiarCadena ENDP

; ArmarLinea: recibe ESI = producto; arma CODIGO|NOMBRE|CENTAVOS|EXIST en lineaBuf, EAX = bytes.
ArmarLinea PROC USES ebx esi edi
    mov ebx, esi
    mov edi, OFFSET lineaBuf
    lea esi, [ebx+OFS_COD]
    call CopiarCadena
    mov BYTE PTR [edi], '|'
    inc edi
    lea esi, [ebx+OFS_NOM]
    call CopiarCadena
    mov BYTE PTR [edi], '|'
    inc edi
    mov eax, [ebx+OFS_PRE]
    push edi
    mov edi, OFFSET numBuffer
    call EnteroACadena
    pop edi
    mov esi, OFFSET numBuffer
    call CopiarCadena
    mov BYTE PTR [edi], '|'
    inc edi
    mov eax, [ebx+OFS_EXI]
    push edi
    mov edi, OFFSET numBuffer
    call EnteroACadena
    pop edi
    mov esi, OFFSET numBuffer
    call CopiarCadena
    mov BYTE PTR [edi], 0Dh
    inc edi
    mov BYTE PTR [edi], 0Ah
    inc edi
    mov eax, edi
    sub eax, OFFSET lineaBuf
    ret
ArmarLinea ENDP

; GuardarArchivo (opción 7): escribe una línea por producto en inventario.txt.
GuardarArchivo PROC USES eax ebx ecx edx esi
    mov edx, OFFSET nombreArchivo
    call CreateOutputFile        ; EAX = handle
    cmp eax, INVALID_HANDLE_VALUE
    je gaErrorCrear
    mov archivoHandle, eax

    mov esi, OFFSET catalogo
    mov ecx, numProd
    cmp ecx, 0
    je gaCerrar
gaLinea:
    call ArmarLinea
    mov ebx, eax                 ; EBX = bytes pedidos (WriteToFile no conserva ECX)
    push ecx
    mov ecx, ebx
    mov eax, archivoHandle
    mov edx, OFFSET lineaBuf
    call WriteToFile             ; EAX = bytes escritos
    pop ecx
    cmp eax, ebx
    jne gaErrorEscribir
    add esi, TAM_PROD
    dec ecx
    jnz gaLinea

gaCerrar:
    mov eax, archivoHandle
    call CloseFile
    mov cambios, 0
    mLinea msgGuardado
    jmp gaFin
gaErrorEscribir:
    mov eax, archivoHandle
    call CloseFile
    mLinea msgErrEscribir
    jmp gaFin
gaErrorCrear:
    mLinea msgErrCrear
gaFin:
    ret
GuardarArchivo ENDP

; LeerCampo: recibe ESI = campo; regresa ECX = largo, AL = carácter que lo terminó.
LeerCampo PROC USES ebx
    mov ebx, esi
    mov ecx, 0
lcCiclo:
    mov al, [ebx]
    cmp al, '|'
    je lcFin
    cmp al, 0Dh
    je lcFin
    cmp al, 0Ah
    je lcFin
    cmp al, 0
    je lcFin
    inc ebx
    inc ecx
    jmp lcCiclo
lcFin:
    ret
LeerCampo ENDP

; ProcesarArchivo: valida bufArchivo y arma catTemp; CF = 1 si el archivo es inválido.
ProcesarArchivo PROC USES eax ecx edx esi edi
    cld
    mov edi, OFFSET catTemp      ; limpio el catálogo temporal
    mov ecx, SIZEOF catTemp
    mov al, 0
    rep stosb
    mov numTemp, 0
    mov esi, OFFSET bufArchivo

paLinea:
    cmp BYTE PTR [esi], 0
    je paFin
    mov eax, numTemp
    cmp eax, MAX_PROD
    jae paError
    imul edi, eax, TAM_PROD
    add edi, OFFSET catTemp

    ; código
    call LeerCampo
    cmp al, '|'
    jne paError
    call ValidarCodigo
    jc paError
    mov edx, esi                 ; reviso que no esté repetido
    push esi
    push ecx
    mov esi, OFFSET catTemp
    mov ecx, numTemp
    call BuscarEnCatalogo
    pop ecx
    pop esi
    jnc paError
    push edi
    rep movsb
    pop edi
    inc esi

    ; nombre
    call LeerCampo
    cmp al, '|'
    jne paError
    mRango ecx, 1, 25
    jc paError
    push edi
    add edi, OFS_NOM
    rep movsb
    pop edi
    inc esi

    ; precio en centavos
    call LeerCampo
    cmp al, '|'
    jne paError
    call ConvertirEntero
    jc paError
    mRango eax, 1, MAX_PRECIO
    jc paError
    mov [edi+OFS_PRE], eax
    add esi, ecx
    inc esi

    ; existencia
    call LeerCampo
    cmp al, '|'                  ; no debe haber más campos
    je paError
    call ConvertirEntero
    jc paError
    cmp eax, MAX_EXIST
    ja paError
    mov [edi+OFS_EXI], eax
    add esi, ecx
    cmp BYTE PTR [esi], 0Dh
    jne paSaltoLinea
    inc esi
paSaltoLinea:
    cmp BYTE PTR [esi], 0Ah
    jne paSiguiente
    inc esi
paSiguiente:
    inc numTemp
    jmp paLinea

paFin:
    clc
    ret
paError:
    stc
    ret
ProcesarArchivo ENDP

; CargarArchivo (opción 8 y al iniciar): reemplaza el catálogo solo si el archivo es válido.
CargarArchivo PROC USES eax ebx ecx edx esi edi
    mov edx, OFFSET nombreArchivo
    call OpenInputFile
    cmp eax, INVALID_HANDLE_VALUE
    je caNoExiste
    mov archivoHandle, eax

    mov edx, OFFSET bufArchivo
    mov ecx, TAM_ARCH
    call ReadFromFile            ; EAX = bytes leídos
    jc caErrorLeer
    mov bytesLeidos, eax
    mov eax, archivoHandle
    call CloseFile

    mov ebx, bytesLeidos
    cmp ebx, TAM_ARCH            ; buffer lleno = archivo demasiado grande
    jae caInvalido
    mov bufArchivo[ebx], 0       ; 00h después de lo leído
    call ProcesarArchivo
    jc caInvalido

    cld
    mov esi, OFFSET catTemp
    mov edi, OFFSET catalogo
    mov ecx, SIZEOF catalogo
    rep movsb
    mov eax, numTemp
    mov numProd, eax
    mov cambios, 0
    mov edx, OFFSET msgCargado
    mov eax, numProd
    call MostrarDato
    jmp caFin

caErrorLeer:
    mov eax, archivoHandle
    call CloseFile
caInvalido:
    mLinea msgArchMal
    jmp caFin
caNoExiste:
    mLinea msgNoArchivo
caFin:
    ret
CargarArchivo ENDP

END main
