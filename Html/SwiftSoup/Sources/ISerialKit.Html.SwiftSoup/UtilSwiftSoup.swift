// The Swift Programming Language
// https://docs.swift.org/swift-book
import SwiftSoup
import SwiftUI

public final class UtilPhCss {
    public static func inlineStylesWithCssParser(_ htmlString: String) throws -> String {
        let doc = try SwiftSoup.parse(htmlString)
        let styleTags = try doc.select("style")
        
        for styleTag in styleTags {
            let css = try styleTag.html()
            let rules = try parseCssRules(css)
            
            for rule in rules {
                let elements = try doc.select(rule.selectors)
                for element in elements {
                    try applyStyles(element: element, styles: rule.styles)
                }
            }
            
            try styleTag.remove()
        }
        
        return try doc.html()
    }
    
    private static func parseCssRules(_ css: String) throws -> [CssRule] {
        // 这里需要实现 CSS 解析逻辑
        // 可以使用第三方 CSS 解析库或简化实现
        return []
    }
    
    private static func applyStyles(element: Element, styles: String) throws {
        let currentStyle = try element.attr("style")
        if currentStyle.isEmpty {
            try element.attr("style", styles)
        } else {
            try element.attr("style", "\(currentStyle); \(styles)")
        }
    }
}

#Preview{
    Text(UtilPhCss.inlineStylesWithCssParser("<span>123</span>"))
}

