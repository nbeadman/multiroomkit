import Foundation

public final class XMLNode {
    public let name: String
    public let attributes: [String: String]
    public var text = ""
    public var children: [XMLNode] = []
    init(name: String, attributes: [String: String] = [:]) {
        self.name = name; self.attributes = attributes
    }
    public func all(_ name: String) -> [XMLNode] {
        (self.name == name ? [self] : []) + children.flatMap { $0.all(name) }
    }
    public func value(_ name: String) -> String? {
        guard let value = all(name).first?.text.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty, value != "NOT_IMPLEMENTED" else { return nil }
        return value
    }
}

private final class XMLTree: NSObject, XMLParserDelegate {
    var stack: [XMLNode] = []
    var root: XMLNode?
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        guard stack.count < 64 else { parser.abortParsing(); return }
        let node = XMLNode(name: elementName.split(separator: ":").last.map(String.init) ?? elementName,
                           attributes: attributeDict)
        stack.last?.children.append(node)
        if root == nil { root = node }
        stack.append(node)
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { stack.last?.text += string }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        stack.last?.text += String(decoding: CDATABlock, as: UTF8.self)
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if !stack.isEmpty { stack.removeLast() }
    }
}

public func parseXML(_ data: Data) throws -> XMLNode {
    guard data.count <= 2_000_000 else { throw StatusError("XML exceeds the prototype size limit.") }
    guard let text = String(data: data, encoding: .utf8), !text.contains("\0") else {
        throw StatusError("Expected UTF-8 XML.")
    }
    guard !text.localizedCaseInsensitiveContains("<!DOCTYPE"),
          !text.localizedCaseInsensitiveContains("<!ENTITY") else { throw StatusError("XML declarations are not allowed.") }
    let parser = XMLParser(data: data)
    parser.shouldResolveExternalEntities = false
    let delegate = XMLTree()
    parser.delegate = delegate
    guard parser.parse(), let root = delegate.root else { throw StatusError("Malformed XML response.") }
    if root.all("Fault").count > 0 { throw StatusError("Speaker returned a SOAP fault.") }
    return root
}

public func parseXML(_ text: String) throws -> XMLNode { try parseXML(Data(text.utf8)) }
