import Foundation

final class XMLNode {
    let name: String
    let attributes: [String: String]
    var text = ""
    var children: [XMLNode] = []

    init(name: String, attributes: [String: String]) {
        self.name = name
        self.attributes = attributes
    }

    func all(_ name: String) -> [XMLNode] {
        (self.name == name ? [self] : []) + children.flatMap { $0.all(name) }
    }

    func value(_ name: String) -> String? {
        guard let value = all(name).first?.text.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty, value != "NOT_IMPLEMENTED" else { return nil }
        return value
    }
}

private final class XMLTree: NSObject, XMLParserDelegate {
    var stack: [XMLNode] = []
    var root: XMLNode?

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        guard stack.count < 64 else { parser.abortParsing(); return }
        let node = XMLNode(name: name.split(separator: ":").last.map(String.init) ?? name, attributes: attributes)
        stack.last?.children.append(node)
        if root == nil { root = node }
        stack.append(node)
    }

    func parser(_ parser: XMLParser, foundCharacters text: String) { stack.last?.text += text }
    func parser(_ parser: XMLParser, foundCDATA data: Data) { stack.last?.text += String(decoding: data, as: UTF8.self) }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if !stack.isEmpty { stack.removeLast() }
    }
}

func parseXML(_ data: Data) throws -> XMLNode {
    guard data.count <= 2_000_000, let text = String(data: data, encoding: .utf8), !text.contains("\0"),
          !text.localizedCaseInsensitiveContains("<!DOCTYPE"), !text.localizedCaseInsensitiveContains("<!ENTITY") else {
        throw MultiroomError.invalidResponse
    }
    let parser = XMLParser(data: data)
    parser.shouldResolveExternalEntities = false
    let tree = XMLTree()
    parser.delegate = tree
    guard parser.parse(), let root = tree.root, root.all("Fault").isEmpty else {
        throw MultiroomError.invalidResponse
    }
    return root
}

func parseXML(_ text: String) throws -> XMLNode { try parseXML(Data(text.utf8)) }
