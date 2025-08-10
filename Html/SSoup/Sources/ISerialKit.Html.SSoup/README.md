功能说明
解析 <style> 标签：提取所有 CSS 规则

CSS 规则处理：

支持类选择器 (.class)

支持 ID 选择器 (#id)

支持标签选择器 (p, div 等)

支持多选择器 (逗号分隔)

样式合并：保留元素原有的内联样式

清理：处理完成后移除 <style> 标签

注意事项
CSS 解析限制：这个实现使用了简单的正则表达式解析 CSS，对于复杂的 CSS 规则可能不够健壮。生产环境中建议集成专业的 CSS 解析库。

SwiftSoup 安装：

通过 Swift Package Manager 添加：

swift
.package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.3.2")
性能考虑：对于非常大的 HTML 文档，可能需要优化选择器查询性能。

错误处理：所有可能抛出异常的操作都标记为 throws，调用时需要处理错误。
