// The Swift Programming Language
// https://docs.swift.org/swift-book
import SwiftSoup
import SwiftUI

public extension String {
    func inlineStylesWithCssParser() throws -> String {
        return try UtilPhCss.inlineStylesWithCssParser(self)
    }
    
    func inlineStylesWithCssParserSafe() throws -> String {
        return try UtilPhCss.inlineStylesWithCssParserSafe(self)
    }
    
    func removeTagsButKeepContent(tag:String) throws ->String{
        return try  UtilPhCss.removeTagsButKeepContent(strHtml: self, tag: tag)
    }
}

//==========================================================>

public final class UtilPhCss {
    //移除特定标签并保留内容
    public static func removeTagsButKeepContent(strHtml: String,tag:String) throws -> String {
        let doc = try SwiftSoup.parse(strHtml)
        let aTags = try doc.select(tag)
        
        // 使用 unwrap() 方法移除标签但保留内容
        try aTags.unwrap()
        
        return try doc.html()
    }
    
    public static func inlineStylesWithCssParserSafe(_ strHtml: String) throws -> String {
        // 安全的使用方式
        do {
            let htmlWithInlineStyles = try strHtml.inlineStylesWithCssParser()
            print("CSS内联处理成功")
            return htmlWithInlineStyles
        } catch {
            print("CSS内联失败: \(error)")
            
            // 降级方案：移除style标签但保留其他内容
            return removeStyleTagsFallback(strHtml)
        }
    }
    
    public static func removeStyleTagsFallback(_ strHtml: String) -> String {
        do {
            let document = try SwiftSoup.parse(strHtml)
            try document.select("style").remove()
            let fallbackHtml = try document.html()
            print("使用降级方案：已移除style标签")
            return fallbackHtml
        } catch {
            print("降级方案也失败: \(error)，返回原始HTML")
            return strHtml
        }
    }
    
    public static func inlineStylesWithCssParser(_ strHtml: String) throws -> String {
        let document = try SwiftSoup.parse(strHtml)
        let styleTags = try document.select("style")
        
        // 收集所有 CSS 规则
        var allRules: [CssRule] = []
        
        for styleTag in styleTags {
            let css = try styleTag.html()
            let rules = try parseCssRules(css)
            
            allRules.append(contentsOf: rules)
            try styleTag.remove()
        }
        
        // 按选择器特异性排序（简单的特异性排序）
        let sortedRules = allRules.sorted { rule1, rule2 in
            // 简单的特异性计算：ID选择器 > 类选择器 > 标签选择器
            let specificity1 = calculateSpecificity(rule1.selectors)
            let specificity2 = calculateSpecificity(rule2.selectors)
            return specificity1 > specificity2
        }
        
        // 应用所有规则
        for rule in sortedRules {
            do {
                // 使用更安全的选择器解析
                let elements = try safelySelectElements(document: document, selector: rule.selectors)
                for element in elements {
                    try applyStyles(element: element, styles: rule.styles)
                }
            } catch {
                // 记录错误但继续处理其他规则
                print("警告: 无法应用CSS规则 '\(rule.selectors)' - \(error)")
                continue
            }
        }
        
        return try document.html()
    }
    
    // 安全的选择器查询方法
    private static func safelySelectElements(document: Document, selector: String) throws -> Elements {
        // 处理包含特殊字符的选择器
        let sanitizedSelector = selector
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { sanitizeSelector($0) }
            .joined(separator: ", ")
        
        if sanitizedSelector.isEmpty {
            return Elements()
        }
        
        return try document.select(sanitizedSelector)
    }
    
    // 清理选择器中的特殊字符
    private static func sanitizeSelector(_ selector: String) -> String {
        var sanitized = selector
        
        // 处理包含方括号的选择器（如 .gap-x-[10px]）
        if selector.contains("[") && selector.contains("]") {
            // 使用属性选择器替代
            if let classPart = selector.components(separatedBy: "[").first?.trimmingCharacters(in: .whitespaces) {
                if classPart.hasPrefix(".") {
                    let className = String(classPart.dropFirst())
                    return "[class*=\"\(className)\"]"
                }
            }
            return "" // 无法处理的选择器
        }
        
        // 处理其他可能的问题字符
        let problematicChars = ["\\", ":", "~", ">", "+", "~", "*"]
        for char in problematicChars {
            if selector.contains(char) && !selector.contains("\\"+char) {
                // 对于复杂选择器，使用更通用的方法
                if selector.hasPrefix(".") {
                    let className = String(selector.dropFirst())
                    return "[class~=\"\(className)\"]"
                }
            }
        }
        
        return sanitized
    }
    
    private static func parseCssRules(_ css: String) throws -> [CssRule] {
        var rules: [CssRule] = []
        
        // 移除注释和空白
        let cleanedCss = css
            .replacingOccurrences(of: "/\\*[^*]*\\*+([^/*][^*]*\\*+)*/", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 分割规则块
        let ruleBlocks = cleanedCss.components(separatedBy: "}")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        for block in ruleBlocks {
            let parts = block.components(separatedBy: "{")
            guard parts.count == 2 else { continue }
            
            let selectorsPart = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let stylesPart = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            if selectorsPart.isEmpty || stylesPart.isEmpty {
                continue
            }
            
            // 处理多个选择器
            let selectors = selectorsPart
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            
            // 清理样式
            let styles = stylesPart
                .components(separatedBy: ";")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { style -> String in
                    // 确保每个样式以分号结尾
                    style.hasSuffix(";") ? style : style + ";"
                }
                .joined(separator: " ")
            
            rules.append(CssRule(selectors: selectors, styles: styles))
        }
        
        return rules
    }
    
    // 简单的特异性计算
    private static func calculateSpecificity(_ selector: String) -> Int {
        var specificity = 0
        
        // ID 选择器
        let idCount = selector.components(separatedBy: "#").count - 1
        specificity += idCount * 100
        
        // 类选择器、属性选择器、伪类
        let classCount = selector.components(separatedBy: ".").count - 1
        let attributeCount = selector.components(separatedBy: "[").count - 1
        let pseudoClassCount = selector.components(separatedBy: ":").count - 1
        specificity += (classCount + attributeCount + pseudoClassCount) * 10
        
        // 标签选择器、伪元素
        let tagCount = selector.components(separatedBy: " ").count // 简单估算
        specificity += tagCount
        
        return specificity
    }
    
    private static func applyStyles(element: Element, styles: String) throws {
        let currentStyle = try element.attr("style")
        
        if currentStyle.isEmpty {
            try element.attr("style", styles)
        } else {
            // 合并样式，新的样式追加到后面（CSS 层叠规则）
            let mergedStyle = currentStyle.hasSuffix(";") ?
            "\(currentStyle) \(styles)" :
            "\(currentStyle); \(styles)"
            try element.attr("style", mergedStyle)
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

