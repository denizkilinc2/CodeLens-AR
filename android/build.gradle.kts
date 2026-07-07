allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// --- CodeLens AR fix block -------------------------------------------------
// ar_flutter_plugin (0.7.3) predates AGP 8 / modern Kotlin defaults, so it is
// missing two things: (1) a Gradle-level namespace, (2) a consistent JVM
// target between its Java and Kotlin compile tasks. We patch both here,
// generically, for any subproject that needs it. This block MUST be declared
// BEFORE evaluationDependsOn(":app") below, otherwise afterEvaluate() throws
// "Cannot run Project.afterEvaluate(Action) when the project is already
// evaluated."
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt is com.android.build.gradle.BaseExtension) {
            // 1) Namespace fix
            if (androidExt.namespace == null) {
                androidExt.namespace = if (project.name == "ar_flutter_plugin") {
                    "io.carius.lars.ar_flutter_plugin"
                } else {
                    "com.codelens.fixedns.${project.name.replace("-", "_")}"
                }
            }
            // 2) JVM target consistency fix (Java side)
            androidExt.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
            androidExt.compileOptions.targetCompatibility = JavaVersion.VERSION_17
        }
        // 2) JVM target consistency fix (Kotlin side)
        // NOTE: the old `kotlinOptions { jvmTarget = "17" }` DSL is REMOVED as of
        // recent Kotlin Gradle Plugin versions (2.x). Must use compilerOptions instead.
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}
// --- end CodeLens AR fix block ---------------------------------------------

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
