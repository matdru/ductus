import NotebookCore
import SwiftUI
import UIKit

/// Book-like page turning with UIKit's page curl. Turning past the last page reveals a fresh blank page, which
/// becomes a real page once the turn completes. The curl only reacts to fingers, so the Pencil always writes.
struct PageCurlView: UIViewControllerRepresentable {
    let model: PrototypeModel
    let notebookID: UUID
    @Binding var currentIndex: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(
            transitionStyle: .pageCurl, navigationOrientation: .horizontal,
            options: [.spineLocation: UIPageViewController.SpineLocation.min.rawValue])
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.view.backgroundColor = .clear
        for recognizer in controller.gestureRecognizers {
            recognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        }
        if let page = context.coordinator.controller(at: currentIndex) {
            controller.setViewControllers([page], direction: .forward, animated: false)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        let shown = (controller.viewControllers?.first as? PageHost)?.index
        guard shown != currentIndex, let page = context.coordinator.controller(at: currentIndex) else { return }
        let direction: UIPageViewController.NavigationDirection = (shown ?? 0) < currentIndex ? .forward : .reverse
        controller.setViewControllers([page], direction: direction, animated: shown != nil)
    }

    /// Hosts one page; `index == pageCount` is the fresh page past the end.
    final class PageHost: UIHostingController<AnyView> {
        let index: Int

        init(index: Int, content: AnyView) {
            self.index = index
            super.init(rootView: content)
            view.backgroundColor = UIColor(DeskColor.surface)
        }

        @available(*, unavailable)
        required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    }

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PageCurlView

        init(_ parent: PageCurlView) {
            self.parent = parent
        }

        private var notebook: Notebook? { parent.model.notebook(parent.notebookID) }

        func controller(at index: Int) -> PageHost? {
            guard let notebook, index >= 0, index <= notebook.pages.count else { return nil }
            let content: AnyView
            if index < notebook.pages.count {
                content = AnyView(
                    PageView(model: parent.model, notebook: notebook, page: notebook.pages[index]).padding(28))
            } else {
                content = AnyView(FreshPage(notebook: notebook).padding(28))
            }
            return PageHost(index: index, content: content)
        }

        func pageViewController(_ controller: UIPageViewController, viewControllerBefore current: UIViewController)
            -> UIViewController?
        {
            guard let host = current as? PageHost else { return nil }
            return self.controller(at: host.index - 1)
        }

        func pageViewController(_ controller: UIPageViewController, viewControllerAfter current: UIViewController)
            -> UIViewController?
        {
            guard let host = current as? PageHost else { return nil }
            return self.controller(at: host.index + 1)
        }

        func pageViewController(
            _ controller: UIPageViewController, didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController], transitionCompleted completed: Bool
        ) {
            guard completed, let host = controller.viewControllers?.first as? PageHost, let notebook else { return }
            if host.index == notebook.pages.count {
                parent.model.update(parent.notebookID) { $0.appendPage() }
                if let real = self.controller(at: host.index) {
                    controller.setViewControllers([real], direction: .forward, animated: false)
                }
            }
            parent.currentIndex = host.index
        }
    }
}

/// The blank page waiting past the end of the notebook.
private struct FreshPage: View {
    let notebook: Notebook

    var body: some View {
        PaperView(paper: notebook.paper, size: notebook.size)
            .overlay {
                Label("New page", systemImage: "plus")
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(.secondary)
            }
            .clipShape(.rect(cornerRadius: 2))
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
    }
}

enum DeskColor {
    static let surface = Color(hex: 0xE9E5DE)
    static let surfaceDark = Color(hex: 0xD8D2C8)
}
