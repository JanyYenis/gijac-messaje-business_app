
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Algunos plugins (p. ej. file_picker) compilan contra un Android más viejo que el que exigen sus dependencias.
// Se sube su compileSdk a 36 (no cambia targetSdk ni minSdk). Debe ir ANTES de evaluationDependsOn.
subprojects {
    if (name != "app") {
        val subir = {
            extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)?.let { lib ->
                val actual = lib.compileSdk ?: 0
                if (actual < 36) lib.compileSdk = 36
            }
        }
        if (state.executed) subir() else afterEvaluate { subir() }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
