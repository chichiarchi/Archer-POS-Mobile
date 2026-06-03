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
    val configureCompileSdk = Action<Project> {
        val androidExtension = extensions.findByName("android")
        if (androidExtension != null) {
            try {
                val setCompileSdk = androidExtension.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                setCompileSdk.invoke(androidExtension, 36)
                println("Forcefully set compileSdk to 36 for: ${name}")
            } catch (e: Exception) {
                try {
                    val compileSdkVersion = androidExtension.javaClass.getMethod("compileSdkVersion", Int::class.java)
                    compileSdkVersion.invoke(androidExtension, 36)
                    println("Forcefully set compileSdkVersion to 36 for: ${name}")
                } catch (ex: Exception) {
                    // Ignore if not a standard Android project
                }
            }
        }
    }

    if (state.executed) {
        configureCompileSdk.execute(this)
    } else {
        afterEvaluate {
            configureCompileSdk.execute(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

