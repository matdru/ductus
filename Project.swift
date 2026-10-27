import ProjectDescription

let deploymentTargets: DeploymentTargets = .iOS("26.0")
let destinations: Destinations = [.iPad]
let baseSettings: Settings = .settings(base: [
    "SWIFT_VERSION": "6.0",
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
])

func module(_ name: String, dependencies: [TargetDependency] = []) -> [Target] {
    [
        .target(
            name: name,
            destinations: destinations,
            product: .framework,
            bundleId: "app.ductus.\(name)",
            deploymentTargets: deploymentTargets,
            sources: ["Modules/\(name)/Sources/**"],
            dependencies: dependencies,
            settings: baseSettings
        ),
        .target(
            name: "\(name)Tests",
            destinations: destinations,
            product: .unitTests,
            bundleId: "app.ductus.\(name)Tests",
            deploymentTargets: deploymentTargets,
            sources: ["Modules/\(name)/Tests/**"],
            dependencies: [.target(name: name)],
            settings: baseSettings
        ),
    ]
}

func app(_ name: String, bundleId: String, dependencies: [TargetDependency], tests: Bool) -> [Target] {
    var targets: [Target] = [
        .target(
            name: name,
            destinations: destinations,
            product: .app,
            bundleId: bundleId,
            deploymentTargets: deploymentTargets,
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
                "UISupportedInterfaceOrientations~ipad": [
                    "UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown",
                    "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight",
                ],
            ]),
            sources: ["Apps/\(name)/Sources/**"],
            resources: ["Apps/\(name)/Resources/**"],
            dependencies: dependencies,
            settings: baseSettings
        )
    ]
    if tests {
        targets.append(
            .target(
                name: "\(name)Tests",
                destinations: destinations,
                product: .unitTests,
                bundleId: "\(bundleId).tests",
                deploymentTargets: deploymentTargets,
                sources: ["Apps/\(name)/Tests/**"],
                dependencies: [.target(name: name)],
                settings: baseSettings
            ))
    }
    return targets
}

let project = Project(
    name: "Ductus",
    settings: baseSettings,
    targets: module("InkCore")
        + module("InkMetal", dependencies: [.target(name: "InkCore")])
        + module("InkPencilKit", dependencies: [.target(name: "InkCore")])
        + module("NotebookCore")
        + module("NotebookStore", dependencies: [.target(name: "NotebookCore")])
        + module("DesignSystem")
        + module("Paper", dependencies: [.target(name: "NotebookCore")])
        + app(
            "FeelLab", bundleId: "app.ductus.feellab",
            dependencies: [.target(name: "InkCore"), .target(name: "InkMetal"), .target(name: "InkPencilKit")],
            tests: true)
        + app(
            "Ductus", bundleId: "app.ductus",
            dependencies: [
                .target(name: "InkCore"), .target(name: "InkPencilKit"), .target(name: "DesignSystem"),
                .target(name: "NotebookCore"), .target(name: "NotebookStore"), .target(name: "Paper"),
            ],
            tests: true)
        // Throwaway look-and-feel prototype (Linear DRU-32); not shipped.
        + app(
            "Prototype", bundleId: "app.ductus.prototype",
            dependencies: [.target(name: "NotebookCore")],
            tests: false)
)
