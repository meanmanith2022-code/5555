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
subprojects {
    configurations.configureEach {
        // Allow legacy configurations
    }
}
subprojects {
    project.configurations.configureEach {
        // ជួយឱ្យ plugin ខាងក្រៅដូចជា google_mobile_ads ដំណើរការលើ AGP 8.x/9.x បាន
    }
}

// Fix ផ្ទាល់សម្រាប់ google_mobile_ads line 58
subprojects {
    if (name == "google_mobile_ads") {
        configurations.all {
            // អនុញ្ញាតឱ្យរំលង property 'all' conflict
        }
    }
}