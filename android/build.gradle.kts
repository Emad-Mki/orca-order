buildscript {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        google()
        mavenCentral()
    }
    dependencies {
        if (file("app/google-services.json").isFile) {
            classpath("com.google.gms:google-services:4.4.2")
        }
    }
}

allprojects {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
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
    plugins.withId("com.android.library") {
        val androidExtension =
            extensions.getByType(com.android.build.gradle.LibraryExtension::class.java)
        androidExtension.compileSdk = 37
        androidExtension.buildTypes.configureEach {
            val configuredProguardFiles = proguardFiles.toList()
            if (configuredProguardFiles.any {
                    it.toString().contains("proguard-android.txt")
                }
            ) {
                setProguardFiles(
                    configuredProguardFiles.map {
                        if (it.toString().contains("proguard-android.txt")) {
                            androidExtension.getDefaultProguardFile(
                                "proguard-android-optimize.txt"
                            )
                        } else {
                            it
                        }
                    }
                )
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
