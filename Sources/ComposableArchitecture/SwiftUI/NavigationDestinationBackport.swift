#if swift(>=5.7)
  import SwiftUI
  import SwiftUINavigation
import NavigationStackBackport

  extension View {
    public func navigationDestination<State, Action, Destination: View>(
      store: Store<PresentationState<State>, PresentationAction<Action>>,
      @ViewBuilder destination: @escaping (Store<State, Action>) -> Destination
    ) -> some View {
        self.navigationDestination(
        store: store, state: { $0 }, action: { $0 }, destination: destination
      )
    }

    public func navigationDestination<
      State, Action, DestinationState, DestinationAction, Destination: View
    >(
      store: Store<PresentationState<State>, PresentationAction<Action>>,
      state toDestinationState: @escaping (State) -> DestinationState?,
      action fromDestinationAction: @escaping (DestinationAction) -> Action,
      @ViewBuilder destination: @escaping (Store<DestinationState, DestinationAction>) ->
        Destination
    ) -> some View {
      self.modifier(
        PresentationNavigationDestinationModifier(
          store: store,
          state: toDestinationState,
          action: fromDestinationAction,
          content: destination
        )
      )
    }
  }

  private struct PresentationNavigationDestinationModifier<
    State,
    Action,
    DestinationState,
    DestinationAction,
    DestinationContent: View
  >: ViewModifier {
    let store: Store<PresentationState<State>, PresentationAction<Action>>
    @StateObject var viewStore: ViewStore<Bool, PresentationAction<Action>>
    let toDestinationState: (State) -> DestinationState?
    let fromDestinationAction: (DestinationAction) -> Action
    let destinationContent: (Store<DestinationState, DestinationAction>) -> DestinationContent

    init(
      store: Store<PresentationState<State>, PresentationAction<Action>>,
      state toDestinationState: @escaping (State) -> DestinationState?,
      action fromDestinationAction: @escaping (DestinationAction) -> Action,
      content destinationContent:
        @escaping (Store<DestinationState, DestinationAction>) -> DestinationContent
    ) {
      self.store = store
      self._viewStore = StateObject(
        wrappedValue: ViewStore(
          store
            .filterSend { state, _ in state.wrappedValue != nil }
            .scope(
              state: { $0.wrappedValue.flatMap(toDestinationState) != nil },
              action: { $0 }
            ),
          observe: { $0 }
        )
      )
      self.toDestinationState = toDestinationState
      self.fromDestinationAction = fromDestinationAction
      self.destinationContent = destinationContent
    }

    func body(content: Content) -> some View {
        content.navigationDestination(
        // TODO: do binding with ID check
        unwrapping: self.viewStore.binding(send: .dismiss).presence
      ) { _ in
        IfLetStore(
          self.store.scope(
            state: returningLastNonNilValue { $0.wrappedValue.flatMap(self.toDestinationState) },
            action: { .presented(self.fromDestinationAction($0)) }
          ),
          then: self.destinationContent
        )
      }
    }
  }

  extension Binding where Value == Bool {
    fileprivate var presence: Binding<Void?> {
      .init(
        get: { self.wrappedValue ? () : nil },
        set: { self.transaction($1).wrappedValue = $0 != nil }
      )
    }
  }
#endif


#if swift(>=5.7)
  import SwiftUI

  extension View {
    /// Pushes a view onto a `NavigationStack` using a binding as a data source for the
    /// destination's content.
    ///
    /// This is a version of SwiftUI's `navigationDestination(isPresented:)` modifier, but powered
    /// by a binding to optional state instead of a binding to a boolean. When state becomes
    /// non-`nil`, a _binding_ to the unwrapped value is passed to the destination closure.
    ///
    /// ```swift
    /// struct TimelineView: View {
    ///   @State var draft: Post?
    ///
    ///   var body: Body {
    ///     Button("Compose") {
    ///       self.draft = Post()
    ///     }
    ///     .navigationDestination(unwrapping: self.$draft) { $draft in
    ///       ComposeView(post: $draft, onSubmit: { ... })
    ///     }
    ///   }
    /// }
    ///
    /// struct ComposeView: View {
    ///   @Binding var post: Post
    ///   var body: some View { ... }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - value: A binding to an optional source of truth for the destination. When `value` is
    ///     non-`nil`, a non-optional binding to the value is passed to the `destination` closure.
    ///     You use this binding to produce content that the system pushes to the user in a
    ///     navigation stack. Changes made to the destination's binding will be reflected back in
    ///     the source of truth. Likewise, changes to `value` are instantly reflected in the
    ///     destination. If `value` becomes `nil`, the destination is popped.
    ///   - destination: A closure returning the content of the destination.
    @ViewBuilder
    public func navigationDestination<Value, Destination: View>(
      unwrapping value: Binding<Value?>,
      @ViewBuilder destination: @escaping (Binding<Value>) -> Destination
    ) -> some View {
      if requiresBindWorkaround {
        self.modifier(
          _NavigationDestinationBindWorkaround(
            isPresented: value.isPresent(),
            destination: Binding(unwrapping: value).map(destination)
          )
        )
      } else {
          self.backport.navigationDestination(isPresented: value.isPresent()) {
          Binding(unwrapping: value).map(destination)
        }
      }
    }

    /// Pushes a view onto a `NavigationStack` using a binding and case path as a data source for
    /// the destination's content.
    ///
    /// A version of `View.navigationDestination(unwrapping:)` that works with enum state.
    ///
    /// - Parameters:
    ///   - enum: A binding to an optional enum that holds the source of truth for the destination
    ///     at a particular case. When `enum` is non-`nil`, and `casePath` successfully extracts a
    ///     value, a non-optional binding to the value is passed to the `content` closure. You use
    ///     this binding to produce content that the system pushes to the user in a navigation
    ///     stack. Changes made to the destination's binding will be reflected back in the source of
    ///     truth. Likewise, changes to `enum` at the given case are instantly reflected in the
    ///     destination. If `enum` becomes `nil`, or becomes a case other than the one identified by
    ///     `casePath`, the destination is popped.
    ///   - casePath: A case path that identifies a case of `enum` that holds a source of truth for
    ///     the destination.
    ///   - destination: A closure returning the content of the destination.
    public func navigationDestination<Enum, Case, Destination: View>(
      unwrapping enum: Binding<Enum?>,
      case casePath: CasePath<Enum, Case>,
      @ViewBuilder destination: @escaping (Binding<Case>) -> Destination
    ) -> some View {
      self.navigationDestination(unwrapping: `enum`.case(casePath), destination: destination)
    }
  }

  // NB: This view modifier works around a bug in SwiftUI's built-in modifier:
  // https://gist.github.com/mbrandonw/f8b94957031160336cac6898a919cbb7#file-fb11056434-md
  private struct _NavigationDestinationBindWorkaround<Destination: View>: ViewModifier {
    @Binding var isPresented: Bool
    let destination: Destination

    @State private var isPresentedState = false

    public func body(content: Content) -> some View {
      content
        .backport
        .navigationDestination(isPresented: self.$isPresentedState) { self.destination }
        .bind(self.$isPresented, to: self.$isPresentedState)
    }
  }

  private let requiresBindWorkaround = {
    guard #available(iOS 16.4, macOS 13.3, tvOS 16.4, watchOS 9.4, *)
    else { return true }
    return false
  }()
#endif
