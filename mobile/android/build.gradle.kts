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
subprojects {
    project.evaluationDependsOn(":app")
}
subprojects {
    if (project.name != "app") {
        val configureSdk = {
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    val m = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                    m.invoke(android, 37)
                } catch (_: Exception) {
                    try {
                        val m = android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                        m.invoke(android, java.lang.Integer.valueOf(37))
                    } catch (_: Exception) {}
                }
            }
        }
        if (state.executed) {
            configureSdk()
        } else {
            afterEvaluate { configureSdk() }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
