import os

# Configuración
ARCHIVOS_A_INCLUIR = ['.dart'] # Extensiones deseadas
CARPETAS_A_IGNORAR = []

def generar_contexto_proyecto(ruta_raiz, archivo_salida):
    with open(archivo_salida, 'w', encoding='utf-8') as out:
        out.write("# ESTRUCTURA DEL PROYECTO\n```text\n")
        
        # Generar un árbol simple
        for raiz, dirs, archivos in os.walk(ruta_raiz):
            dirs[:] = [d for d in dirs if d not in CARPETAS_A_IGNORAR]
            nivel = raiz.replace(ruta_raiz, '').count(os.sep)
            indentacion = ' ' * 4 * (nivel)
            out.write(f'{indentacion}{os.path.basename(raiz)}/\n')
            sub_indentacion = ' ' * 4 * (nivel + 1)
            for f in archivos:
                if any(f.endswith(ext) for ext in ARCHIVOS_A_INCLUIR):
                    out.write(f'{sub_indentacion}{f}\n')
        
        out.write("```\n\n# CÓDIGO FUENTE\n\n")

        # Consolidar contenido
        for raiz, dirs, archivos in os.walk(ruta_raiz):
            dirs[:] = [d for d in dirs if d not in CARPETAS_A_IGNORAR]
            for f in archivos:
                if any(f.endswith(ext) for ext in ARCHIVOS_A_INCLUIR) and f != os.path.basename(archivo_salida):
                    ruta_completa = os.path.join(raiz, f)
                    ruta_relativa = os.path.relpath(ruta_completa, ruta_raiz)
                    
                    out.write(f"### ARCHIVO: {ruta_relativa}\n")
                    out.write(f"```python\n")
                    try:
                        with open(ruta_completa, 'r', encoding='utf-8') as archivo_codigo:
                            out.write(archivo_codigo.read())
                    except Exception as e:
                        out.write(f"# Error al leer el archivo: {e}\n")
                    out.write("\n```\n\n")

if __name__ == "__main__":
    generar_contexto_proyecto('.', 'contexto_proyecto.txt')
    print("¡Archivo 'contexto_proyecto.txt' generado con éxito!")