// The Swift Programming Language
// https://docs.swift.org/swift-book
import SwiftSoup
import SwiftUI

public extension String {
    func inlineStylesWithCssParser() throws -> String {
        return try UtilPhCss.inlineStylesWithCssParser(self)
    }
}

//==========================================================>

public final class UtilPhCss {
    public static func inlineStylesWithCssParser(_ htmlString: String) throws -> String {
        let document = try SwiftSoup.parse(htmlString)
        let styleTags = try document.select("style")
        
        for styleTag in styleTags {
            let css = try styleTag.html()
            let rules = try parseCssRules(css)
            
            for rule in rules {
                let elements = try document.select(rule.selectors)
                for element in elements {
                    try applyStyles(element: element, styles: rule.styles)
                }
            }
            
            try styleTag.remove()
        }
        
        return try document.html()
    }
    
    private static func parseCssRules(_ css: String) throws -> [CssRule] {
        var rules: [CssRule] = []
        
        // 移除注释
        let cleanedCss = css.replacingOccurrences(of: "/\\*.*?\\*/", with: "", options: .regularExpression)
        
        // 按规则分割，先处理@media规则
        let parts = cleanedCss.components(separatedBy: "@media")
        
        // 只处理第一部分（非@media内容）
        let nonMediaCss = parts.first ?? ""
        
        let rulePattern = "([^{]+)\\s*\\{([^}]*)\\}"
        let regex = try NSRegularExpression(pattern: rulePattern)
        
        let matches = regex.matches(in: nonMediaCss, range: NSRange(nonMediaCss.startIndex..., in: nonMediaCss))
        
        for match in matches {
            guard let selectorsRange = Range(match.range(at: 1), in: cleanedCss),
                  let stylesRange = Range(match.range(at: 2), in: cleanedCss) else { continue }
            
            let selectors = String(cleanedCss[selectorsRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .joined(separator: ", ")
            
            let styles = String(cleanedCss[stylesRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: ";")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "; ")
            
            if !selectors.isEmpty && !styles.isEmpty {
                rules.append(CssRule(selectors: selectors, styles: styles))
            }
        }
        
        return rules
    }
    
    private static func applyStyles(element: Element, styles: String) throws {
        let currentStyle = try element.attr("style")
        if currentStyle.isEmpty {
            try element.attr("style", styles)
        } else {
            // 合并样式，避免覆盖已有样式
            try element.attr("style", "\(currentStyle); \(styles)")
        }
    }
}

#Preview{
    Text("<span>123</span>")
        .onAppear(perform: {
            do {
                let html = """
                <html>
                <head>
                <style>
                .title {
                    color: blue;
                    font-size: 20px;
                }
                p {
                    margin: 10px;
                    padding: 5px;
                }
                #special {
                    background-color: yellow;
                }
                </style>
                </head>
                <body>
                <h1 class="title">Hello World</h1>
                <p>This is a paragraph</p>
                <div id="special">Special content</div>
                </body>
                </html>
                """
                
                let result = try html.inlineStylesWithCssParser()
                print(result)
            } catch {
                print("Error: \(error)")
            }
        })
}

