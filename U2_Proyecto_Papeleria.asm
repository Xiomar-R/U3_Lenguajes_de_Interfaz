; Materia: Lenguajes de Interfaz
; Alumno: Eber Angulo Ramirez
; Horario: 8 a 9
; Docente: Dr. José Luis Medina Jiménez
; Proyecto: Unidad 2. Sistema de ventas e inventario
; Negocio: Papelería "El Lápiz"
; Descripción: Registro, búsqueda, entradas, ventas, resumen, guardado y carga
;              de hasta 10 productos usando Irvine32. Los números se capturan
;              con ReadString y se muestran con WriteString usando conversiones
;              propias (sin ReadDec, ReadInt, ParseDecimal32, WriteDec ni WriteHex).


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
MAX_EXIST  = 100         ; existencia máxima
DESC_MIN   = 10          ; piezas mínimas para el descuento (10% = dividir entre 10)
TAM_ARCH   = 1024        ; capacidad del buffer del archivo

.data
    ; ---------- catálogo ----------
    catalogo     BYTE MAX_PROD * TAM_PROD DUP(0)
    numProd      DWORD 0                 ; productos registrados
    ingresos     DWORD 0                 ; ingresos de la sesión en centavos
    cambios      BYTE 0                  ; 1 = hay cambios sin guardar

    ; catálogo temporal para validar el archivo antes de reemplazar el real
    catTemp      BYTE MAX_PROD * TAM_PROD DUP(0)
    numTemp      DWORD 0

    ; ---------- datos de captura ----------
    entrada      BYTE 41 DUP(0)          ; lo que teclea el usuario
    numBuffer    BYTE 12 DUP(0)          ; número convertido a texto

    ; ---------- archivo ----------
    nombreArchivo BYTE "inventario.txt", 0
    archivoHandle DWORD 0
    bufArchivo   BYTE TAM_ARCH + 1 DUP(0) ; +1 para poner el 00h
    bytesLeidos  DWORD 0
    lineaBuf     BYTE 64 DUP(0)

    ; ---------- mensajes ----------
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
    mov edx, OFFSET titulo       ; muestro el nombre del sistema
    call MostrarLinea
    call CargarArchivo           ; intento recuperar el catálogo guardado

menuPrincipal:
    call Crlf
    mov edx, OFFSET txtMenu      ; muestro el menú
    call WriteString
    mov edx, OFFSET msgOpcion
    call LeerEntrada             ; EAX = caracteres tecleados
    cmp eax, 1                   ; la opción debe ser de un solo carácter
    jne opcionMala
    mov al, entrada              ; tomo el carácter tecleado
    cmp al, '1'
    je op1
    cmp al, '2'
    je op2
    cmp al, '3'
    je op3
    cmp al, '4'
    je op4
    cmp al, '5'
    je op5
    cmp al, '6'
    je op6
    cmp al, '7'
    je op7
    cmp al, '8'
    je op8
    cmp al, '9'
    je op9
opcionMala:
    mov edx, OFFSET msgOpcionMal ; cualquier otra cosa es inválida
    call MostrarLinea
    jmp menuPrincipal            ; vuelvo a mostrar el menú

op1:
    call RegistrarProducto
    jmp menuPrincipal
op2:
    call MostrarInventario
    jmp menuPrincipal
op3:
    call BuscarProducto
    jmp menuPrincipal
op4:
    call RecibirMercancia
    jmp menuPrincipal
op5:
    call Vender
    jmp menuPrincipal
op6:
    call MostrarResumen
    jmp menuPrincipal
op7:
    call GuardarArchivo
    jmp menuPrincipal
op8:
    call CargarArchivo
    jmp menuPrincipal

op9:
    cmp cambios, 0               ; reviso si hay cambios sin guardar
    je salir
    mov edx, OFFSET msgSalir     ; aviso antes de salir
    call LeerEntrada
    mov al, entrada
    cmp al, 'S'
    je salir
    cmp al, 's'
    je salir
    jmp menuPrincipal            ; si no confirma, regreso al menú

salir:
    mov edx, OFFSET msgAdios
    call MostrarLinea
    exit                         ; termino el programa
main ENDP

;==================================================================
; PROCEDIMIENTOS DE ENTRADA Y SALIDA
;==================================================================

MostrarLinea PROC
    call WriteString
    call Crlf
    ret
MostrarLinea ENDP

LeerEntrada PROC
    push ecx
    push edx
    call WriteString             ; muestro el mensaje
    mov edx, OFFSET entrada      ; EDX = dirección donde quedará el texto
    mov ecx, SIZEOF entrada - 1  ; ECX = máximo de caracteres (dejo lugar al 00h)
    call ReadString              ; EAX regresa cuántos caracteres se leyeron
    pop edx
    pop ecx
    ret
LeerEntrada ENDP

EnteroACadena PROC
    pushad
    mov ebx, 10                  ; divisor 10 para separar los dígitos
    mov ecx, 0                   ; ECX cuenta los dígitos
ecDividir:
    mov edx, 0                   ; limpio EDX: el dividendo es EDX:EAX
    div ebx                      ; EAX = cociente, EDX = residuo 
    add dl, '0'                  ; paso el residuo a su código ASCII
    push edx                     ; los dígitos salen al revés, los guardo en la pila
    inc ecx
    cmp eax, 0                   ; sigo mientras el cociente no sea cero
    jne ecDividir
ecSacar:
    pop edx                      ; los saco en el orden correcto
    mov [edi], dl
    inc edi
    loop ecSacar
    mov BYTE PTR [edi], 0        ; pongo el fin de cadena
    popad
    ret
EnteroACadena ENDP

MostrarNumero PROC
    push edx
    push edi
    mov edi, OFFSET numBuffer
    call EnteroACadena           ; convierto el número a texto
    mov edx, OFFSET numBuffer
    call WriteString             ; y lo muestro
    pop edi
    pop edx
    ret
MostrarNumero ENDP

MostrarMXN PROC
    push eax
    push ebx
    push edx
    mov edx, 0                   ; preparo el dividendo EDX:EAX
    mov ebx, 100
    div ebx                      ; EAX = pesos, EDX = centavos
    mov ebx, eax                 ; guardo los pesos en EBX
    mov al, '$'
    call WriteChar
    mov eax, ebx
    call MostrarNumero           ; muestro los pesos
    mov al, '.'
    call WriteChar
    mov eax, edx                 ; EAX = centavos
    cmp eax, 10                  ; si es menor que 10 le pongo un 0 antes (5 -> 05)
    jae mmCentavos
    push eax
    mov al, '0'
    call WriteChar
    pop eax
mmCentavos:
    call MostrarNumero           ; muestro los centavos
    mov edx, OFFSET txtMXN       ; agrego la etiqueta MXN
    call WriteString
    pop edx
    pop ebx
    pop eax
    ret
MostrarMXN ENDP

;==================================================================
; PROCEDIMIENTOS DE VALIDACIÓN Y CONVERSIÓN
;==================================================================

ValidarCodigo PROC
    push eax
    push ecx
    push esi
    cmp ecx, 7                   ; el código mide exactamente 7 caracteres
    jne vcError
    mov ecx, 3                   ; reviso las 3 letras
vcLetras:
    mov al, [esi]
    cmp al, 'A'
    jb vcError
    cmp al, 'Z'
    ja vcError
    inc esi
    loop vcLetras
    cmp BYTE PTR [esi], '-'      ; luego debe venir el guion
    jne vcError
    inc esi
    mov ecx, 3                   ; reviso los 3 dígitos
vcDigitos:
    mov al, [esi]
    cmp al, '0'
    jb vcError
    cmp al, '9'
    ja vcError
    inc esi
    loop vcDigitos
    clc                          ; código correcto
    jmp vcFin
vcError:
    stc                          ; código incorrecto
vcFin:
    pop esi                      ; POP no cambia las banderas
    pop ecx
    pop eax
    ret
ValidarCodigo ENDP

ConvertirEntero PROC
    push ecx
    push edx
    push esi
    cmp ecx, 0                   ; rechazo la cadena vacía
    je ceError
    cmp ecx, 9                   ; más de 9 dígitos puede desbordar
    ja ceError
    mov eax, 0                   ; EAX acumula el valor
ceCiclo:
    movzx edx, BYTE PTR [esi]
    cmp dl, '0'                  ; solo acepto dígitos
    jb ceError
    cmp dl, '9'
    ja ceError
    sub dl, '0'                  ; ASCII a valor numérico
    imul eax, eax, 10            ; recorro una posición decimal
    jo ceError                   ; compruebo desbordamiento
    add eax, edx                 ; sumo el dígito
    jc ceError
    inc esi
    loop ceCiclo
    clc
    jmp ceFin
ceError:
    stc
ceFin:
    pop esi
    pop edx
    pop ecx
    ret
ConvertirEntero ENDP

ConvertirPrecio PROC
    push ebx
    push ecx
    push edx
    push esi
    mov edx, ecx                 ; EDX = largo total del texto
    mov ecx, 0                   ; ECX cuenta los caracteres antes del punto
cpBuscaPunto:
    cmp ecx, edx                 ; ¿llegué al final sin encontrar punto?
    je cpPesos
    cmp BYTE PTR [esi+ecx], '.'  ; ¿encontré el punto?
    je cpPesos
    inc ecx
    jmp cpBuscaPunto

cpPesos:
    cmp ecx, 4                   ; más de 4 dígitos ya pasa de 9999
    ja cpError
    call ConvertirEntero         ; EAX = pesos (CF = 1 si está vacío o no son dígitos)
    jc cpError
    imul ebx, eax, 100           ; EBX = pesos convertidos a centavos
    sub edx, ecx                 ; EDX = lo que sobra: el punto y los decimales
    cmp edx, 0                   ; si no sobra nada no hubo punto
    je cpRango

    add esi, ecx                 ; ESI apunta al punto
    inc esi                      ; ESI apunta al primer decimal
    mov ecx, edx
    dec ecx                      ; ECX = cantidad de decimales
    cmp ecx, 2                   ; un tercer decimal se rechaza
    ja cpError
    call ConvertirEntero         ; EAX = decimales (CF = 1 si "185." no trae decimales)
    jc cpError
    cmp ecx, 2                   ; con 2 decimales ya son centavos
    je cpSumar
    imul eax, eax, 10            ; con 1 decimal: ".5" son 50 centavos
cpSumar:
    add ebx, eax                 ; EBX = pesos + centavos

cpRango:
    mov eax, ebx                 ; EAX = precio total en centavos
    cmp eax, 1                   ; mínimo $0.01
    jb cpError
    cmp eax, MAX_PRECIO          ; máximo $9999.99
    ja cpError
    clc
    jmp cpFin
cpError:
    stc
cpFin:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
ConvertirPrecio ENDP

;==================================================================
; PROCEDIMIENTOS DE BÚSQUEDA
;==================================================================

BuscarEnCatalogo PROC
    push eax
    push ebx
    push ecx
    cmp ecx, 0                   ; si no hay productos no existe
    je bcNoEsta
bcSiguiente:
    mov ebx, 0                   ; EBX = posición del carácter
bcComparar:
    mov al, [edx+ebx]
    cmp al, [esi+ebx+OFS_COD]    ; comparo carácter por carácter
    jne bcOtro
    inc ebx
    cmp ebx, 7
    jb bcComparar
    clc                          ; los 7 caracteres coinciden
    jmp bcFin
bcOtro:
    add esi, TAM_PROD            ; ESI avanza al siguiente producto
    loop bcSiguiente
bcNoEsta:
    stc
bcFin:
    pop ecx
    pop ebx
    pop eax
    ret
BuscarEnCatalogo ENDP

BuscarCodigo PROC
    push ecx
    mov esi, OFFSET catalogo     ; ESI empieza en el primer producto
    mov ecx, numProd
    call BuscarEnCatalogo
    pop ecx
    ret
BuscarCodigo ENDP

PedirCodigo PROC
    push eax
    push ecx
    push edx
    push esi
pcoPedir:
    mov edx, OFFSET msgPideCodigo
    call LeerEntrada             ; EAX = largo de lo capturado
    mov esi, OFFSET entrada
    mov ecx, eax
    call ValidarCodigo
    jnc pcoFin                   ; formato correcto
    mov edx, OFFSET msgCodigoMal
    call MostrarLinea
    jmp pcoPedir                 ; repito la captura
pcoFin:
    pop esi
    pop edx
    pop ecx
    pop eax
    ret
PedirCodigo ENDP

PedirProducto PROC
    push edx
    call PedirCodigo
    mov edx, OFFSET entrada
    call BuscarCodigo
    jnc ppFin                    ; lo encontré
    mov edx, OFFSET msgNoExiste
    call MostrarLinea
    stc                          ; vuelvo a poner CF porque WriteString lo pudo cambiar
ppFin:
    pop edx
    ret
PedirProducto ENDP

PedirCantidad PROC
    push ecx
    push edx
    push esi
pcaPedir:
    mov edx, OFFSET msgPideCant
    call LeerEntrada
    mov esi, OFFSET entrada
    mov ecx, eax
    call ConvertirEntero         ; EAX = cantidad, CF = 1 si es inválida
    jc pcaMal
    cmp eax, 1                   ; debe ser mayor que cero
    jae pcaFin
pcaMal:
    mov edx, OFFSET msgCantMal
    call MostrarLinea
    jmp pcaPedir
pcaFin:
    pop esi
    pop edx
    pop ecx
    ret
PedirCantidad ENDP

;==================================================================
; FUNCIONES DEL MENÚ
;==================================================================

RegistrarProducto PROC
    pushad
    cld
    cmp numProd, MAX_PROD        ; reviso la capacidad
    jb rpCodigo
    mov edx, OFFSET msgLleno
    call MostrarLinea
    jmp rpFin

rpCodigo:
    call PedirCodigo
    mov edx, OFFSET entrada
    call BuscarCodigo            ; CF = 0 significa que ya existe
    jc rpNuevo
    mov edx, OFFSET msgDuplicado
    call MostrarLinea
    jmp rpFin
rpNuevo:
    mov eax, numProd             ; EBX = lugar libre = catalogo + numProd * 44
    imul ebx, eax, TAM_PROD
    add ebx, OFFSET catalogo
    mov esi, OFFSET entrada      ; copio el código (8 bytes con su 00h)
    lea edi, [ebx+OFS_COD]
    mov ecx, TAM_COD
    rep movsb

rpNombre:
    mov edx, OFFSET msgPideNombre
    call LeerEntrada
    cmp eax, 1                   ; rechazo el nombre vacío
    jb rpNombreMal
    cmp eax, 25                  ; y el que pase de 25 caracteres
    ja rpNombreMal
    mov esi, OFFSET entrada
    mov ecx, eax
rpRevisa:
    cmp BYTE PTR [esi], '|'      ; el | se usa como separador en el archivo
    je rpNombreMal
    inc esi
    loop rpRevisa
    mov esi, OFFSET entrada      ; copio el nombre con su 00h
    lea edi, [ebx+OFS_NOM]
    mov ecx, eax
    inc ecx
    rep movsb
    jmp rpPrecio
rpNombreMal:
    mov edx, OFFSET msgNombreMal
    call MostrarLinea
    jmp rpNombre

rpPrecio:
    mov edx, OFFSET msgPidePrecio
    call LeerEntrada
    mov esi, OFFSET entrada
    mov ecx, eax
    call ConvertirPrecio         ; EAX = centavos
    jnc rpPrecioOk
    mov edx, OFFSET msgPrecioMal
    call MostrarLinea
    jmp rpPrecio
rpPrecioOk:
    mov [ebx+OFS_PRE], eax       ; guardo el precio en centavos

rpExist:
    mov edx, OFFSET msgPideExist
    call LeerEntrada
    mov esi, OFFSET entrada
    mov ecx, eax
    call ConvertirEntero
    jc rpExistMal
    cmp eax, MAX_EXIST
    jbe rpGuardar
rpExistMal:
    mov edx, OFFSET msgExistMal
    call MostrarLinea
    jmp rpExist

rpGuardar:
    mov [ebx+OFS_EXI], eax       ; guardo la existencia
    inc numProd                  ; ahora sí el producto forma parte del catálogo
    mov cambios, 1
    mov edx, OFFSET msgRegistrado
    call MostrarLinea
rpFin:
    popad
    ret
RegistrarProducto ENDP

MostrarProducto PROC
    pushad
    lea edx, [esi+OFS_COD]       ; código
    call WriteString
    mov edx, OFFSET txtSep
    call WriteString
    lea edx, [esi+OFS_NOM]       ; nombre
    call WriteString
    call StrLength               ; EAX = largo del nombre
    mov ecx, 28
    sub ecx, eax                 ; espacios para alinear la columna
mpRelleno:
    mov al, ' '
    call WriteChar
    loop mpRelleno
    mov eax, [esi+OFS_PRE]       ; precio
    call MostrarMXN
    mov edx, OFFSET txtSep
    call WriteString
    mov eax, [esi+OFS_EXI]       ; existencia
    call MostrarNumero
    call Crlf
    popad
    ret
MostrarProducto ENDP

MostrarInventario PROC
    pushad
    mov ecx, numProd
    cmp ecx, 0
    jne miHay
    mov edx, OFFSET msgVacio
    call MostrarLinea
    jmp miFin
miHay:
    mov edx, OFFSET msgEncabezado
    call MostrarLinea
    mov esi, OFFSET catalogo     ; ESI apunta al primer producto
miCiclo:
    call MostrarProducto
    add esi, TAM_PROD            ; avanzo al siguiente producto
    loop miCiclo
miFin:
    popad
    ret
MostrarInventario ENDP

BuscarProducto PROC
    pushad
    call PedirProducto           ; ESI = producto
    jc bpFin
    mov edx, OFFSET msgEncabezado
    call MostrarLinea
    call MostrarProducto
bpFin:
    popad
    ret
BuscarProducto ENDP

RecibirMercancia PROC
    pushad
    call PedirProducto           ; ESI = producto
    jc rmFin
    call PedirCantidad           ; EAX = unidades recibidas
    mov ebx, [esi+OFS_EXI]
    add ebx, eax                 ; EBX = nueva existencia
    cmp ebx, MAX_EXIST
    ja rmExcede                  ; no se modifica nada
    mov [esi+OFS_EXI], ebx       ; actualizo la existencia
    mov cambios, 1
    mov edx, OFFSET msgEntradaOk
    call WriteString
    mov eax, ebx
    call MostrarNumero
    call Crlf
    jmp rmFin
rmExcede:
    mov edx, OFFSET msgExcede
    call MostrarLinea
rmFin:
    popad
    ret
RecibirMercancia ENDP

Vender PROC
    pushad
    call PedirProducto           ; ESI = producto
    jc veFin
    call PedirCantidad           ; EAX = cantidad
    mov ecx, eax                 ; ECX = piezas a vender
    cmp ecx, [esi+OFS_EXI]       ; ¿alcanza la existencia?
    ja veSinExist

    mov eax, [esi+OFS_PRE]
    mul ecx                      ; EDX:EAX = precio * cantidad
    jc veDesborde                ; CF = 1 si el resultado no cabe en EAX
    mov ebx, eax                 ; EBX = importe base
    mov edx, OFFSET msgImporte
    call WriteString
    mov eax, ebx
    call MostrarMXN
    call Crlf

    ; regla del negocio: 10% de descuento desde 10 piezas
    cmp ecx, DESC_MIN
    jb veSinDesc
    mov eax, ebx
    mov edx, 0
    mov edi, 10
    div edi                      ; EAX = importe / 10 = 10% (se descarta el residuo)
    mov edx, OFFSET msgDescuento
    call WriteString
    call MostrarMXN
    call Crlf
    sub ebx, eax                 ; EBX = importe final
    jmp veTotal
veSinDesc:
    mov edx, OFFSET msgSinDesc
    call MostrarLinea

veTotal:
    mov eax, ingresos
    add eax, ebx                 ; calculo los nuevos ingresos
    jc veDesborde                ; si desborda no se registra la venta
    mov edx, OFFSET msgTotal
    call WriteString
    push eax
    mov eax, ebx
    call MostrarMXN
    call Crlf
    pop eax
    mov ingresos, eax            ; ahora sí actualizo ingresos
    sub [esi+OFS_EXI], ecx       ; y descuento las piezas vendidas
    mov cambios, 1
    mov edx, OFFSET msgVentaOk
    call WriteString
    mov eax, [esi+OFS_EXI]
    call MostrarNumero
    call Crlf
    jmp veFin

veSinExist:
    mov edx, OFFSET msgSinExist
    call MostrarLinea
    jmp veFin
veDesborde:
    mov edx, OFFSET msgDesborde
    call MostrarLinea
veFin:
    popad
    ret
Vender ENDP

MostrarResumen PROC
    pushad
    mov esi, OFFSET catalogo
    mov ecx, numProd
    mov ebx, 0                   ; EBX = unidades
    mov edi, 0                   ; EDI = valor del inventario
    cmp ecx, 0
    je mrMostrar
mrCiclo:
    add ebx, [esi+OFS_EXI]       ; sumo existencias
    mov eax, [esi+OFS_PRE]
    mul DWORD PTR [esi+OFS_EXI]  ; EDX:EAX = precio * existencia
    jc mrDesborde                ; CF = 1 si no cabe en EAX
    add edi, eax                 ; acumulo el valor
    jc mrDesborde                ; CF = 1 si la suma desborda
    add esi, TAM_PROD            ; siguiente producto
    loop mrCiclo

mrMostrar:
    mov edx, OFFSET msgResTit
    call MostrarLinea
    mov edx, OFFSET msgResProd
    call WriteString
    mov eax, numProd
    call MostrarNumero
    call Crlf
    mov edx, OFFSET msgResUnid
    call WriteString
    mov eax, ebx
    call MostrarNumero
    call Crlf
    mov edx, OFFSET msgResValor
    call WriteString
    mov eax, edi
    call MostrarMXN
    call Crlf
    mov edx, OFFSET msgResIngr
    call WriteString
    mov eax, ingresos
    call MostrarMXN
    call Crlf
    jmp mrFin
mrDesborde:
    mov edx, OFFSET msgDesborde
    call MostrarLinea
mrFin:
    popad
    ret
MostrarResumen ENDP

;==================================================================
; ARCHIVOS
;==================================================================

CopiarCadena PROC
    push eax
    push esi
ccCiclo:
    mov al, [esi]
    cmp al, 0
    je ccFin
    mov [edi], al
    inc esi
    inc edi
    jmp ccCiclo
ccFin:
    pop esi
    pop eax
    ret
CopiarCadena ENDP

ArmarLinea PROC
    push ebx
    push esi
    push edi
    mov ebx, esi                 ; EBX = producto
    mov edi, OFFSET lineaBuf
    lea esi, [ebx+OFS_COD]
    call CopiarCadena            ; código
    mov BYTE PTR [edi], '|'
    inc edi
    lea esi, [ebx+OFS_NOM]
    call CopiarCadena            ; nombre
    mov BYTE PTR [edi], '|'
    inc edi
    mov eax, [ebx+OFS_PRE]       ; precio en centavos a texto
    push edi
    mov edi, OFFSET numBuffer
    call EnteroACadena
    pop edi
    mov esi, OFFSET numBuffer
    call CopiarCadena
    mov BYTE PTR [edi], '|'
    inc edi
    mov eax, [ebx+OFS_EXI]       ; existencia a texto
    push edi
    mov edi, OFFSET numBuffer
    call EnteroACadena
    pop edi
    mov esi, OFFSET numBuffer
    call CopiarCadena
    mov BYTE PTR [edi], 0Dh      ; fin de línea
    inc edi
    mov BYTE PTR [edi], 0Ah
    inc edi
    mov eax, edi
    sub eax, OFFSET lineaBuf     ; EAX = bytes de la línea
    pop edi
    pop esi
    pop ebx
    ret
ArmarLinea ENDP

GuardarArchivo PROC
    pushad
    mov edx, OFFSET nombreArchivo
    call CreateOutputFile        ; EAX = handle del archivo
    cmp eax, INVALID_HANDLE_VALUE
    je gaErrorCrear
    mov archivoHandle, eax

    mov esi, OFFSET catalogo     ; ESI recorre los productos
    mov ecx, numProd
    cmp ecx, 0
    je gaCerrar
gaLinea:
    call ArmarLinea              ; EAX = bytes de la línea
    mov ebx, eax                 ; EBX = bytes solicitados (WriteToFile no conserva ECX)
    push ecx                     ; guardo el contador de productos
    mov ecx, ebx                 ; ECX = bytes a escribir
    mov eax, archivoHandle       ; EAX = handle
    mov edx, OFFSET lineaBuf     ; EDX = datos
    call WriteToFile             ; EAX = bytes escritos
    pop ecx
    cmp eax, ebx                 ; verifico que se escribió todo
    jne gaErrorEscribir
    add esi, TAM_PROD
    dec ecx
    jnz gaLinea

gaCerrar:
    mov eax, archivoHandle
    call CloseFile
    mov cambios, 0               ; ya no hay cambios pendientes
    mov edx, OFFSET msgGuardado
    call MostrarLinea
    jmp gaFin
gaErrorEscribir:
    mov eax, archivoHandle
    call CloseFile
    mov edx, OFFSET msgErrEscribir
    call MostrarLinea
    jmp gaFin
gaErrorCrear:
    mov edx, OFFSET msgErrCrear
    call MostrarLinea
gaFin:
    popad
    ret
GuardarArchivo ENDP

LeerCampo PROC
    push ebx
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
    pop ebx
    ret
LeerCampo ENDP

ProcesarArchivo PROC
    pushad
    cld
    mov edi, OFFSET catTemp      ; limpio el catálogo temporal
    mov ecx, SIZEOF catTemp
    mov al, 0
    rep stosb
    mov numTemp, 0
    mov esi, OFFSET bufArchivo   ; ESI recorre el texto del archivo

paLinea:
    cmp BYTE PTR [esi], 0        ; ¿terminó el archivo?
    je paFin
    mov eax, numTemp
    cmp eax, MAX_PROD            ; más de 10 productos es inválido
    jae paError
    imul edi, eax, TAM_PROD
    add edi, OFFSET catTemp      ; EDI = producto destino

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
    jnc paError                  ; código duplicado
    push edi
    rep movsb                    ; copio los 7 caracteres (ESI avanza)
    pop edi
    inc esi                      ; salto el |

    ; nombre
    call LeerCampo
    cmp al, '|'
    jne paError
    cmp ecx, 1
    jb paError
    cmp ecx, 25
    ja paError
    push edi
    add edi, OFS_NOM
    rep movsb                    ; copio el nombre (el 00h ya está por la limpieza)
    pop edi
    inc esi

    ; precio en centavos
    call LeerCampo
    cmp al, '|'
    jne paError
    call ConvertirEntero
    jc paError
    cmp eax, 1
    jb paError
    cmp eax, MAX_PRECIO
    ja paError
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
    cmp BYTE PTR [esi], 0Dh      ; salto el fin de línea
    jne paSaltoLinea
    inc esi
paSaltoLinea:
    cmp BYTE PTR [esi], 0Ah
    jne paSiguiente
    inc esi
paSiguiente:
    inc numTemp                  ; producto válido
    jmp paLinea

paFin:
    popad
    clc
    ret
paError:
    popad
    stc
    ret
ProcesarArchivo ENDP

CargarArchivo PROC
    pushad
    mov edx, OFFSET nombreArchivo
    call OpenInputFile           ; EAX = handle
    cmp eax, INVALID_HANDLE_VALUE
    je caNoExiste
    mov archivoHandle, eax

    mov edx, OFFSET bufArchivo   ; EDX = buffer
    mov ecx, TAM_ARCH            ; ECX = capacidad (dejo 1 byte para el 00h)
    call ReadFromFile            ; EAX = bytes leídos, CF = 1 si hubo error
    jc caErrorLeer
    mov bytesLeidos, eax
    mov eax, archivoHandle
    call CloseFile

    mov ebx, bytesLeidos
    cmp ebx, TAM_ARCH            ; si llenó el buffer, el archivo es demasiado grande
    jae caInvalido
    mov bufArchivo[ebx], 0       ; pongo 00h justo después de lo leído
    call ProcesarArchivo
    jc caInvalido

    cld
    mov esi, OFFSET catTemp      ; el archivo es válido: reemplazo el catálogo
    mov edi, OFFSET catalogo
    mov ecx, SIZEOF catalogo
    rep movsb
    mov eax, numTemp
    mov numProd, eax
    mov cambios, 0
    mov edx, OFFSET msgCargado
    call WriteString
    mov eax, numProd
    call MostrarNumero
    call Crlf
    jmp caFin

caErrorLeer:
    mov eax, archivoHandle
    call CloseFile
caInvalido:
    mov edx, OFFSET msgArchMal
    call MostrarLinea
    jmp caFin
caNoExiste:
    mov edx, OFFSET msgNoArchivo
    call MostrarLinea
caFin:
    popad
    ret
CargarArchivo ENDP

END main
