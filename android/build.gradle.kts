import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
        // 国内镜像优先，找不到再回落到官方源
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/central")
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

// 部分插件自带的 compileSdk 偏低（onnxruntime 1.4.1 硬编码 33），
// 而 Flutter embedding 拉进来的 androidx 已要求 34+，
// 于是 :onnxruntime:checkReleaseAarMetadata 报 15 条 AAR metadata 不匹配。
// 这里把偏低的 library 子模块统一抬到 app 的 compileSdk（flutter.compileSdkVersion = 36）。
//
// 两处时机都必须卡准：
// 1. 注册要放在下面 evaluationDependsOn(":app") 之前 —— 那会让 :app 提前完成评估，
//    之后再注册 afterEvaluate 会抛 "project is already evaluated"。
// 2. 必须用 afterEvaluate（而不是 plugins.withId 回调里改）—— AGP 在评估脚本的过程中
//    就读走了 compileSdk，插件 apply 时去改会报 "It is too late to set compileSdk"。
subprojects {
    afterEvaluate {
        if (pluginManager.hasPlugin("com.android.library")) {
            val android = extensions.getByType<LibraryExtension>()
            if ((android.compileSdk ?: 0) < 36) {
                android.compileSdk = 36
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
