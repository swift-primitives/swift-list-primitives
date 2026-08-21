public import Index_Primitives
public import List_Primitive

extension List where Element: ~Copyable {

    public typealias Index = Index_Primitives.Index<Element>
}
