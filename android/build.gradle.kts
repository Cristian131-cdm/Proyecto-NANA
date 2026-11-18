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
// vosk_flutter («Oye NANA» sin bip) compila con la API 33 de Android y otras
// librerías ya piden 34 o más. Se sube solo esa librería, al cerrar su
// configuración (si se hace antes, su build.gradle lo vuelve a poner en 33).
subprojects {
    if (project.name == "vosk_flutter") {
        plugins.withId("com.android.library") {
            extensions.configure<com.android.build.api.variant.LibraryAndroidComponentsExtension> {
                finalizeDsl { it.compileSdk = 36 }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
