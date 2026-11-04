/// A workspace as drawn in the bar's workspace row.
struct WorkspaceGroup: Identifiable, Hashable {
    let name: String
    let isVisible: Bool
    let isFocused: Bool
    let windows: [AeroSpaceWindow]

    var id: String { name }
}
