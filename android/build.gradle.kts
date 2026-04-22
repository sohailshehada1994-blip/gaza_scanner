buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // محرك الأندرويد الأساسي
        classpath("com.android.tools.build:gradle:8.2.1")
        // المحرك المسؤول عن قراءة ملف google-services.json
        classpath("com.google.gms:google-services:4.4.1")
        // دعم لغة كوتلن
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.8.22")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// كود تنظيم مسارات البناء (الذي تستخدمه في مشروعك)
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
