//
//  SwiftInvokeParser.swift
//  Drafter
//
//  Created by LZephyr on 2017/11/12.
//

import Foundation

class SwiftInvokeParser: ParserType {
    
    var parser: Parser<[MethodInvokeNode]> {
        return methodInvoke.continuous.map({ (methods) -> [MethodInvokeNode] in
            var result = methods
            for method in methods {
                result.append(contentsOf: method.params.reduce([]) { $0 + $1.invokes })
            }
            return result
        })
    }
}

// MARK: - Parser

extension SwiftInvokeParser {
    
    /// method_invoke = single_method ('.' single_method)
    var methodInvoke: Parser<MethodInvokeNode> {
        let methodSequence = singleMethod
            .separateBy(token(.dot))
            .map({ (methods) -> MethodInvokeNode in
                methods.dropFirst().reduce(methods[0]) { (last, current) in
                    current.invoker = .method(last)
                    return current
                }
            })
        
        return methodSequence <|> singleMethod
    }
    
    // FIXME: 尾随闭包
    
    /// 匹配一个单独的方法调用
    /// single_method = (invoker '.')? NAME '(' param_list? ')'
    var singleMethod: Parser<MethodInvokeNode> {
        return curry(MethodInvokeNode.swiftInit)
            <^> token(.name) => stringify // 方法名
            <*> paramList.between(token(.leftParen), token(.rightParen)) // 参数列表
    }
    
    /// 解析一个参数列表, 该parser不会失败
    /**
     param_list = param (param ',')*
     */
    var paramList: Parser<[InvokeParam]> {
        // FIXME: 目前没有匹配数字，如 method(2) 这种情况无法正确解析参数
        return lookAhead(token(.rightParen)) *> pure([])
            <|> param.separateBy(token(.comma))
    }
    
    /// 解析单个参数，该parser不会失败
    /**
     param =  (NAME ':')? param_body
     */
    var param: Parser<InvokeParam> {
        return curry(InvokeParam.init)
            <^> trying (token(.name) <* token(.colon)) => stringify
            <*> trying (paramBody) ?? []
    }
    
    /// 匹配参数体中的的方法调用，没有则为空
    var paramBody: Parser<[MethodInvokeNode]> {
        // 处理闭包定义中的方法调用
        let closure = { lazy(self.singleMethod).continuous.run($0) ?? [] }
            <^> anyTokens(inside: token(.leftBrace), and: token(.rightBrace)) // 匹配闭包中的所有token

        // FIXME: 要匹配任意方法调用
        return closure // closure
            <|> curry({ [$0] }) <^> lazy(self.singleMethod) // 方法调用
            <|> anyTokens(until: token(.rightParen) <|> token(.comma)) *> pure([]) // 其他直接忽略
    }
}

extension MethodInvokeNode {
    static func swiftInit(methodName: String, _ params: [InvokeParam]) -> MethodInvokeNode {
        let invoke = MethodInvokeNode()
        invoke.isSwift = true
        invoke.params = params
        invoke.methodName = methodName
        return invoke
    }
}
