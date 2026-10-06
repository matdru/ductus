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

let project = Project(
    name: "Ductus",
    settings: baseSettings,
    targets: module("InkCore")
)
