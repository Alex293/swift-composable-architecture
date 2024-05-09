import SwiftUI
import NavigationStackBackport
@testable @_spi(Internals) import ComposableArchitecture

@available(iOS 14, macOS 13, tvOS 16, watchOS 9, *)
extension NavigationStackBackport.NavigationStack {
  /// Drives a navigation stack with a store.
  ///
  /// See the dedicated article on <doc:Navigation> for more information on the library's
  /// navigation tools, and in particular see <doc:StackBasedNavigation> for information on using
  /// this view.
  public init<State, Action, Destination: View, R>(
    path: Binding<Store<StackState<State>, StackAction<State, Action>>>,
    root: () -> R,
    @ViewBuilder destination: @escaping (Store<State, Action>) -> Destination,
    fileID: StaticString = #fileID,
    line: UInt = #line
  )
  where
  Data == StackState<State>.PathView,
  Root == ModifiedContent<R, _NavigationDestinationViewModifier2<State, Action, Destination>>
  {
    self.init(path: path[fileID: "\(fileID)", line: line]) {
      root()
        .modifier(
          _NavigationDestinationViewModifier2(store: path.wrappedValue, destination: destination)
        )
    }
  }
}

@available(iOS 14, macOS 13, tvOS 16, watchOS 9, *)
public struct _NavigationDestinationViewModifier2<
  State: ObservableState, Action, Destination: View
>:
  ViewModifier
{
  @SwiftUI.State var store: Store<StackState<State>, StackAction<State, Action>>
  fileprivate let destination: (Store<State, Action>) -> Destination

  public func body(content: Content) -> some View {
    content
      .environment(\.navigationDestinationType, State.self)
      .backport
      .navigationDestination(for: StackState<State>.Component.self) { component in
        var element = component.element
        self
          .destination(
            self.store.scope(
              id: self.store.id(state: \.[id:component.id], action: \.[id:component.id]),
              state: ToState {
                element = $0[id: component.id] ?? element
                return element
              },
              action: { .element(id: component.id, action: $0) },
              isInvalid: { !$0.ids.contains(component.id) }
            )
          )
          .environment(\.navigationDestinationType, State.self)
      }
  }
}

@available(iOS 14, macOS 13, tvOS 16, watchOS 9, *)
extension NavigationStackBackport.NavigationLink { //} where Destination == Never {
  /// Creates a navigation link that presents the view corresponding to an element of
  /// ``StackState``.
  ///
  /// When someone activates the navigation link that this initializer creates, SwiftUI looks for
  /// a parent `NavigationStack` view with a store of ``StackState`` containing elements that
  /// matches the type of this initializer's `state` input.
  ///
  /// See SwiftUI's documentation for `NavigationLink.init(value:label:)` for more.
  ///
  /// - Parameters:
  ///   - state: An optional value to present. When the user selects the link, SwiftUI stores a
  ///     copy of the value. Pass a `nil` value to disable the link.
  ///   - label: A label that describes the view that this link presents.
  public init<P, L: View>(
    state: P?,
    @ViewBuilder label: () -> L,
    fileID: StaticString = #fileID,
    line: UInt = #line
  )
  where Label == _NavigationLinkStoreContent<P, L> {
    @Dependency(\.stackElementID) var stackElementID
    self.init(value: state.map { StackState.Component(id: stackElementID(), element: $0) }) {
      _NavigationLinkStoreContent<P, L>(
        state: state, label: { label() }, fileID: fileID, line: line
      )
    }
  }

  /// Creates a navigation link that presents the view corresponding to an element of
  /// ``StackState``, with a text label that the link generates from a localized string key.
  ///
  /// When someone activates the navigation link that this initializer creates, SwiftUI looks for
  /// a parent ``NavigationStackStore`` view with a store of ``StackState`` containing elements
  /// that matches the type of this initializer's `state` input.
  ///
  /// See SwiftUI's documentation for `NavigationLink.init(_:value:)` for more.
  ///
  /// - Parameters:
  ///   - titleKey: A localized string that describes the view that this link
  ///     presents.
  ///   - state: An optional value to present. When the user selects the link, SwiftUI stores a
  ///     copy of the value. Pass a `nil` value to disable the link.
  public init<P>(
    _ titleKey: LocalizedStringKey, state: P?, fileID: StaticString = #fileID, line: UInt = #line
  )
  where Label == _NavigationLinkStoreContent<P, Text> {
    self.init(state: state, label: { Text(titleKey) }, fileID: fileID, line: line)
  }

  /// Creates a navigation link that presents the view corresponding to an element of
  /// ``StackState``, with a text label that the link generates from a title string.
  ///
  /// When someone activates the navigation link that this initializer creates, SwiftUI looks for
  /// a parent ``NavigationStackStore`` view with a store of ``StackState`` containing elements
  /// that matches the type of this initializer's `state` input.
  ///
  /// See SwiftUI's documentation for `NavigationLink.init(_:value:)` for more.
  ///
  /// - Parameters:
  ///   - title: A string that describes the view that this link presents.
  ///   - state: An optional value to present. When the user selects the link, SwiftUI stores a
  ///     copy of the value. Pass a `nil` value to disable the link.
  @_disfavoredOverload
  public init<S: StringProtocol, P>(
    _ title: S, state: P?, fileID: StaticString = #fileID, line: UInt = #line
  )
  where Label == _NavigationLinkStoreContent<P, Text> {
    self.init(state: state, label: { Text(title) }, fileID: fileID, line: line)
  }
}

extension Store where State: ObservableState {
  fileprivate subscript<ElementState, ElementAction>(
    state state: KeyPath<State, StackState<ElementState>>,
    action action: CaseKeyPath<Action, StackAction<ElementState, ElementAction>>,
    isInViewBody isInViewBody: Bool = _isInPerceptionTracking
  ) -> Store<StackState<ElementState>, StackAction<ElementState, ElementAction>> {
    get {
#if DEBUG && !os(visionOS)
      _PerceptionLocals.$isInPerceptionTracking.withValue(isInViewBody) {
        self.scope(state: state, action: action)
      }
#else
      self.scope(state: state, action: action)
#endif
    }
    set {}
  }
}
