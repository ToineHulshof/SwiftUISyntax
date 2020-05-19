//
//  StructTranslator.swift
//  SwiftUISyntax
//
//  Created by Toine Hulshof on 07/03/2020.
//  Copyright c 2020 Toine Hulshof. All rights reserved.
//

import Foundation
import SwiftSyntax
import Foundation

struct StructTranslator {
    
    let node: StructDeclSyntax
    private var isPreview: Bool {
        node.inheritanceClause?.description.contains("PreviewProvider") ?? false
    }
    private var isView: Bool {
        node.inheritanceClause?.description.contains("View") ?? false
    }
    
    func translate() -> String {
        var s = ""
        if !isView && !isPreview {
            KotlinTokenizer().translate(content: node.description).tokens?.forEach({ token in
                s += token.value
            })
            return s
        }
        if isPreview { s += "@Preview\n" }
        s += "@Composable\n"
        s += "fun \(node.identifier)"
        let (initializedMembers, uninitializedMembers, initializer) = splitMembers(node.members.members)
        if let initializer = initializer {
            s += initializer.parameters.description
        } else {
            s += "("
            s += uninitializedMembers.compactMap({ member in
                if let varDecl = member.decl as? VariableDeclSyntax {
                    return varDecl.bindings.description.replacingOccurrences(of: "[", with: "List<").replacingOccurrences(of: "]", with: ">")
                }
                return nil
            }).joined(separator: ", ")
            s += ") "
        }
        s += "{" + newLine()
        initializedMembers.forEach { member in
            switch member.decl {
            case let varDecl as VariableDeclSyntax: s += tab() + translate(varDecl) + newLine()
            case let initDecl as InitializerDeclSyntax: print(initDecl.body?.description ?? "empty init")
            default: break
            }
        }
        s += "}"
        node.members.members.forEach { member in
            if let funcDecl = member.decl as? FunctionDeclSyntax {
                s += translateToKotlin(funcDecl) + newLine()
            }
        }
        return s
    }
    
    func splitMembers(_ members: MemberDeclListSyntax) -> ([MemberDeclListItemSyntax], [MemberDeclListItemSyntax], InitializerDeclSyntax?) {
        var initializedMembers = [MemberDeclListItemSyntax]()
        var uninitializedMembers = [MemberDeclListItemSyntax]()
        var initializer: InitializerDeclSyntax? = nil
        members.forEach { member in
            switch member.decl {
            case let varDecl as VariableDeclSyntax:
                var shouldTranslate = false
                varDecl.bindings.forEach { pattern in
                    if pattern.initializer != nil || ((pattern.accessor as? CodeBlockSyntax) != nil) {
                        shouldTranslate = true
                    }
                }
                if let attributes = varDecl.attributes {
                    attributes.forEach { attribute in
                        if (attribute as? CustomAttributeSyntax) != nil {
                            shouldTranslate = true
                        }
                    }
                }
                shouldTranslate ? initializedMembers.append(member) : uninitializedMembers.append(member)
            case let initDecl as InitializerDeclSyntax: initializer = initDecl
            default: break
            }
        }
        return (initializedMembers, uninitializedMembers, initializer)
    }
        
    func translate(_ decl: DeclSyntax) -> String {
        switch decl {
        case let varDecl as VariableDeclSyntax: return translate(varDecl)
        case let funcDecl as FunctionDeclSyntax: return translateToKotlin(funcDecl)
        default: return "unsupported\n"
        }
    }
    
    func translate(_ decl: VariableDeclSyntax) -> String {
        var s = ""
        if let name = decl.bindings.firstToken, let view = getView(decl.bindings), name.text == "previews" {
            return "MaterialTheme {\n\t\t\(translate(view, 1))\n\t}"
        }
        if let name = decl.bindings.firstToken, let view = getView(decl.bindings), name.text == "body" {
            return translate(view, 2)
        }
        if !decl.withoutTrivia().description.starts(with: "@") {
            let translation = translateToKotlin(decl.withoutTrivia())
            return translation.trimmingCharacters(in: .whitespacesAndNewlines) + newLine()
        }
        switch decl.letOrVarKeyword.text {
        case "var": s += "val "
        case "let": s += "let "
        default: break
        }
        if let attribute = decl.attributes {
            s += decl.bindings.firstToken?.text ?? ""
            s += " = "
            switch attribute.description {
            case let str where str.contains("@State"): s += "+state{\(value(decl.bindings))}"
            case let str where str.contains("@ObservedObject"): s += "+observed{\(value(decl.bindings))}"
            case let str where str.contains("@Binding"): s += "+binding{\(value(decl.bindings))}"
            case let str where str.contains("@EnvironmentObject"): s += decl.bindings.firstToken?.text.capitalizingFirstLetter() ?? ""//s += "+environment{\(value(decl.bindings))}"
            case let str where str.contains("@FetchRequest"): s += "+fetch{\(value(decl.bindings))}"
            default: break
            }
        } else {
            decl.bindings.forEach { binding in
                s += binding.withoutTrivia().description
            }
        }
        return s
    }
    
    func translate(_ codeBlock: CodeBlockSyntax, _ depth: Int) -> String {
        var s = ""
        codeBlock.statements.forEach { view in
            s += translateView(view, depth)
        }
        return s
    }
    
    func translateView(_ view: CodeBlockItemSyntax, _ depth: Int) -> String {
        var s = ""
        switch view.item {
        case let funcExpr as FunctionCallExprSyntax:
            switch funcExpr.calledExpression {
            case let idenExpr as IdentifierExprSyntax: s += translateViewBody(funcExpr, [], idenExpr, depth)
            case let memExpr as MemberAccessExprSyntax: s += translate(view: memExpr, [(memExpr.name.text, funcExpr.argumentList)], depth)
            default: break
            }
        case let memExpr as MemberAccessExprSyntax:
            if let base = memExpr.base {
                switch base {
                case let idenExpr as IdentifierExprSyntax:
                    switch idenExpr.identifier.text {
                    case "Color": s += "Color.\(memExpr.name.text.capitalizingFirstLetter())"
                    default: break
                    }
                default: break
                }
            }
        case let ifStmt as IfStmtSyntax:
            s += "if (" + translateToKotlin(ifStmt.conditions.withoutTrivia()).trimmingCharacters(in: .whitespacesAndNewlines) + ") {\n"
            ifStmt.body.statements.forEach { statement in
                s += tab(depth) + translateView(statement, depth + 1)
            }
            s += newLine() + tab(depth - 1) + "}"
            if let elseBody = ifStmt.elseBody as? CodeBlockSyntax {
                s += " else {\n"
                elseBody.statements.forEach { statement in
                    s += tab(depth) + translateView(statement, depth + 1)
                }
                s += newLine() + tab(depth - 1) + "}"
            }
//            print("if statement", ifStmt.body.)
        default: break
        }
        return s
    }
    
    func translate(view: MemberAccessExprSyntax, _ modifiers: [(String, Syntax)], _ depth: Int) -> String {
        guard let base = view.base else { return "" }
        var s = ""
        switch base {
        case let funcExpr as FunctionCallExprSyntax:
            switch funcExpr.calledExpression {
            case let mem as MemberAccessExprSyntax: s += translate(view: mem, modifiers + [(mem.name.text, funcExpr.argumentList)], depth)
            case let iden as IdentifierExprSyntax:
                let (_, _, navigations, _, _, _) = translateModifiers(modifiers)
                if navigations.isEmpty {
                    s += translateViewBody(funcExpr, modifiers, iden, depth)
                } else {
                    s += "Scaffold(" + newLine() + tab(depth) + "topAppBar = {" + newLine() + tab(depth + 1) + "TopAppBar(" + newLine() + tab(depth + 2) + "title = { Text(text = \(navigations[0])) }" + newLine() + tab(depth + 1) + ")" + newLine() + tab(depth) + "}," + newLine() + tab(depth) + "bodyContent = {" + newLine() + tab(depth + 1) + translateViewBody(funcExpr, modifiers, iden, depth) + newLine() + tab(depth) + "}" + newLine() + tab(depth - 1) + ")"
                }
            default: break
            }
        default: break
        }
        ///TODO: viewmodifiers toevoegen
//        s += newLine() + tab(depth) + "."
//        switch memExpr.name.text {
//        case "foregroundColor": s += "color"
//        default: s += "custom modifier"
//        }
        return s
    }
    
    func translateModifier(_ modifier: (String, Syntax)) -> String {
        var s = ""
        switch modifier.1 {
        case let member as MemberAccessExprSyntax:
            switch modifier.0 {
            case "alignment": s += translateAlignment(member)
            default: break
            }
        case let arguments as FunctionCallArgumentListSyntax:
            switch modifier.0 {
            case "padding": s += translatePadding(arguments)
            case "frame": s += translateFrame(arguments)
            case "shadow": s += translateShadow(arguments)
            case "overlay": s += translateOverlay(arguments)
            case "clipShape": s += translateClipShape(arguments)
            case "font": s += translateFont(arguments)
            case "foregroundColor": s += translateForegroundColor(arguments)
            case "offset": s += translateOffset(arguments)
            case "navigationBarTitle": s += translateNavigationBarTitle(arguments)
            case "cornerRadius": s += translateCornerRadius(arguments)
            case "scaledToFill": s += "ScaleFit.FillWidth"
            case "scaledToFit": s += "ScaleFit.Fit"
            default: s += "\(modifier.0) not implemented yet"
            }
        default: break
        }
        return s
    }
    
    func translateNavigationBarTitle(_ arguments: FunctionCallArgumentListSyntax) -> String {
        var title = ""
        arguments.forEach { argument in
            guard let expr = argument.expression as? FunctionCallExprSyntax else { return }
            expr.argumentList.forEach { argument in
                guard let string = argument.expression as? StringLiteralExprSyntax else { return }
                title = translate(string)
            }
        }
        return title
    }
    
    func translateCornerRadius(_ arguments: FunctionCallArgumentListSyntax) -> String {
        var radius = "5"
        arguments.forEach { argument in
            guard let value = argument.expression as? IntegerLiteralExprSyntax else { return }
            radius = value.withoutTrivia().description
        }
        return "Modifier.clip(RoundedCornerShape(\(radius).dp))"
    }
    
    func translateOffset(_ arguments: FunctionCallArgumentListSyntax) -> String {
        var x = 0
        var y = 0
        arguments.forEach { argument in
            guard let label = argument.label?.text, let value = argument.expression as? IntegerLiteralExprSyntax, let int = Int(value.withoutTrivia().description), int >= 0 else { return }
            // Cannot translate negative padding, because App will crash
            switch label {
            case "x": x = int
            case "y": y = int
            default: break
            }
        }
        return "Modifier.offset(x = \(x).dp, y = \(y).dp)"
    }
    
    func translateForegroundColor(_ arguments: FunctionCallArgumentListSyntax) -> String {
        var color = "black"
        arguments.forEach { argument in
            guard let mem = argument.expression as? MemberAccessExprSyntax else { return }
            switch mem.name.text {
            case "primary": color = "black"
            case "secondary": color = "gray"
            default: color = mem.name.text
            }
        }
        return "color = Color.\(color.capitalizingFirstLetter())"
    }
    
    func translateClipShape(_ arguments: FunctionCallArgumentListSyntax) -> String {
        var shape = "Rectangle"
        arguments.forEach { argument in
            guard let expr = argument.expression as? FunctionCallExprSyntax, let iden = expr.calledExpression as? IdentifierExprSyntax else { return }
            shape = iden.identifier.text
        }
        return "Modifier.clip(\(shape)Shape)"
    }
    
    func translateOverlay(_ arguments: FunctionCallArgumentListSyntax) -> String {
        var color = "black"
        var width = "5"
        arguments.forEach { argument in
            guard let shape = argument.expression as? FunctionCallExprSyntax else { return }
            // Not full support for other kinds of overlays. Just borders for now
            shape.argumentList.forEach { argument in
                if let colorMember = argument.expression as? MemberAccessExprSyntax {
                    color = colorMember.name.text
                }
                if let label = argument.label?.text, label == "lineWidth", let value = argument.expression as? IntegerLiteralExprSyntax {
                    width = value.withoutTrivia().description
                }
            }
        }
        return "Border(\(width).dp, Color.\(color.capitalizingFirstLetter())"
    }
    
    func translateShadow(_ arguments: FunctionCallArgumentListSyntax) -> String {
        var radius = "10"
        arguments.forEach { argument in
            guard let label = argument.label?.text, label == "radius", let value = argument.expression as? IntegerLiteralExprSyntax else { return }
            radius = "\(value.withoutTrivia().description)"
        }
        return "Modifier.drawShadow(shape = CircleShape, elevation = \(radius).dp)"
    }
    
    func translateAlignment(_ member: MemberAccessExprSyntax) -> String {
        var s = "Modifier.wrapContentSize(Alignment."
        switch member.withoutTrivia().description {
        case ".top": s += "TopCenter"
        case ".bottom": s += "BottomCenter"
        case ".leading": s += "CenterStart"
        case ".trailing": s += "CenterEnd"
        default: s += "Center"
        }
        s += ")"
        return s
    }
    
    func translateFrame(_ arguments: FunctionCallArgumentListSyntax) -> String {
        var modifiers = [String]()
        arguments.forEach { argument in
            guard let label = argument.label?.text, let value = argument.expression as? IntegerLiteralExprSyntax else { return }
            var modifier = "Modifier."
            switch label {
            case "height": modifier += "preferredHeight(\(value.withoutTrivia().description).dp)"
            case "width": modifier += "preferredWidth(\(value.withoutTrivia().description).dp)"
            case "minWidth": modifier += "Modifier.fillMaxWidth()"
            case "minHeight": modifier += "Modifier.fillMaxHeight()"
            default: break
            }
            modifiers.append(modifier)
        }
        return modifiers.joined(separator: " + ")
    }
    
    func translatePadding(_ arguments: FunctionCallArgumentListSyntax) -> String {
        var s = "Modifier.padding("
        var edges = [String]() // Can also be implemented as a set, but then order is not preserved.
        var padding = "10.dp"
        arguments.forEach { argument in
            switch argument.expression {
            case let memExpr as MemberAccessExprSyntax: edges += getEdge(memExpr.name.text)
            case let array as ArrayExprSyntax:
                array.elements.forEach { element in
                    guard let memExpr = element.expression as? MemberAccessExprSyntax else { return }
                    edges += getEdge(memExpr.name.text)
                }
            case let intLit as IntegerLiteralExprSyntax: padding = intLit.withoutTrivia().description + ".dp"
            default: break
            }
        }
        s += edges.isEmpty ? padding : edges.map({ "\($0) = \(padding)" }).joined(separator: ", ")
        s += ")"
        return s
    }
    
    func getEdge(_ edge: String) -> [String] {
        switch edge {
        case "top": return ["top"]
        case "bottom": return ["bottom"]
        case "leading": return ["start"]
        case "trailing": return ["end"]
        case "horizontal": return ["start", "end"]
        case "vertical": return ["top", "bottom"]
        case "all": return ["top", "bottom", "start", "end"]
        default: return []
        }
    }
    
    func translateViewBody(_ viewBody: FunctionCallExprSyntax, _ modifiers: [(String, Syntax)], _ idenExpr: IdentifierExprSyntax, _ depth: Int) -> String {
        var s = ""
        ///TODO: zo veel mogelijk views toevoegen
        switch idenExpr.identifier.text {
        case "VStack": s += translateStack(.VStack, viewBody, modifiers, depth)
        case "HStack": s += translateStack(.HStack, viewBody, modifiers, depth)
        case "ZStack": s += translateStack(.ZStack, viewBody, modifiers, depth)
        case "Text": s += translateText(viewBody, modifiers, depth)
        case "Button": s += translateButton(viewBody, depth)
        case "ForEach": s += translateForEach(viewBody, depth)
        case "AngularGradient": s += "AngularGradient not implemented yet"
        case "AnyView": s += "AnyView not implemented yet"
        case "ButtonStyleConfiguration.Label": s += "ButtonStyleConfiguration.Label not implemented yet"
        case "Color":
            s += "Color."
            print(viewBody)
        case "DatePicker": s += "DatePicker not implemented yet"
        case "Divider": s += "Divider()"
        case "EditButton": s += "EditButton not implemented yet"
        case "EmptyView": s += "EmptyView not implemented yet"
        case "EquatableView": s += "EquatableView not implemented yet"
        case "Form": s += "Form not implemented yet"
        case "GeometryReader": s += "GeometryReader not implemented yet"
        case "Group": s += "Group not implemented yet"
        case "GroupBox": s += "GroupBox not implemented yet"
        case "HSplitView": s += "HSplitView not implemented yet"
        case "Image": s += translateImage(viewBody, modifiers, depth)
        case "LinearGradient": s += "LinearGradient not implemented yet"
        case "List":
            guard let closureExpr = viewBody.trailingClosure else { return "" }
            s += "VerticalScroller {\n"
            s += tab(depth) + "Column {\n"
            closureExpr.statements.forEach { view in
                s += tab(depth + 1) + translateView(view, depth + 2) + newLine()
            }
            s += tab(depth) + "}" + newLine()
            s += tab(depth - 1) + "}"
        case "MenuButton": s += "MenuButton not implemented yet"
        case "ModifiedContent": s += "ModifiedContent not implemented yet"
        case "NavigationLink":
            var destination = ""
            viewBody.argumentList.forEach { argument in
                guard let label = argument.label, label.text == "destination" else { return }
                if let view = argument.expression as? FunctionCallExprSyntax {
                    let funcExpr = getLink(view)
                    guard let identifier = funcExpr.calledExpression as? IdentifierExprSyntax else { return }
                    destination += identifier.identifier.text
                    destination += funcExpr.argumentList.count > 0 ? "(" + funcExpr.argumentList.map({ $0.expression.description }).joined(separator: ", ") + ")" : ""
                }
            }
            guard let closure = viewBody.trailingClosure else { return s }
            var views = ""
            closure.statements.forEach { statement in
                views += translateView(statement, depth + 1)
            }
            s += "Clickable(onClick = { navigateTo(Screen.\(destination)) }, modifier = Modifier.ripple() + Modifier.fillMaxWidth() + Modifier.padding(10.dp)) {" + newLine() + tab(depth) + views + newLine() + tab(depth - 1) + "}"
            
        case "NavigationView":
            guard let closureExpr = viewBody.trailingClosure else { return "" }
            closureExpr.statements.forEach { statement in
                s += tab(depth) + translateView(statement, depth) + newLine()
            }
        case "Never": s += "Never not implemented yet"
        case "Optional": s += "Optional not implemented yet"
        case "PasteButton": s += "PasteButton not implemented yet"
        case "Picker": s += "Picker not implemented yet"
        case "PrimitiveButtonStyleConfiguration.Label": s += "PrimitiveButtonStyleConfiguration.Label not implemented yet"
        case "RadialGradient": s += "RadialGradient not implemented yet"
        case "ScrollView":
            guard let closureExpr = viewBody.trailingClosure else { return "" }
            let (_, viewModifiers, _, _, _, _) = translateModifiers(modifiers)
            s += "HorizontalScroller"
            s += viewModifiers.isEmpty ? "" : "(modifier = " + viewModifiers.joined(separator: " + ") + ")"
            s += " {" + newLine()
            closureExpr.statements.forEach { statement in
                s += tab(depth) + translateView(statement, depth + 1) + newLine()
            }
            s += tab(depth - 1) + "}"
        case "Section":
            guard let closureExpr = viewBody.trailingClosure else { return "" }
            s += "Section {\n"
            closureExpr.statements.forEach { statement in
                s += tab(depth) + translateView(statement, depth + 1) + newLine()
            }
            s += tab(depth-1) + "}"
        case "SecureField": s += "SecureField not implemented yet"
        case "Slider": s += "Slider not implemented yet"
        case "Spacer":
            s += "Spacer(modifier = Modifier.weight(1f, true))"
        case "Stepper": s += "Stepper not implemented yet"
        case "SubscriptionView": s += "SubscriptionView not implemented yet"
        case "TabView": s += "TabView not implemented yet"
        case "TextField": s += "TextField not implemented yet"
        case "Toggle":
            var boolean = ""
            viewBody.argumentList.forEach { argument in
                guard let label = argument.label, label.text == "isOn" else { return }
                boolean = argument.expression.description.replacingOccurrences(of: "$", with: "")
            }
            s += "Switch(checked = \(boolean), onCheckedChange = { \(boolean) = it })"
            if let closure = viewBody.trailingClosure {
                s = "Row(modifier = Modifier.fillMaxWidth() + Modifier.padding(10.dp), arrangement = Arrangement.SpaceBetween) {" + newLine() + tab(depth) +                 closure.statements.map({ translateView($0, depth + 1) }).joined(separator: newLine() + tab(depth)) + newLine() + tab(depth) + s + newLine() + tab(depth - 1) + "}"
            }
        case "ToggleStyleConfiguration.Label": s += "ToggleStyleConfiguration.Label not implemented yet"
        case "TupleView": s += "TupleView not implemented yet"
        case "VSplitView": s += "VSplitView not implemented yet"
        default: s += translateCustom(viewBody, idenExpr, modifiers, depth)
        }
        s += ""
        return s
    }
    
    func getLink(_ funcExpr: FunctionCallExprSyntax) -> FunctionCallExprSyntax {
        switch funcExpr.calledExpression {
        case let member as MemberAccessExprSyntax:
            guard let base = member.base, let deepFunc = base as? FunctionCallExprSyntax else { return funcExpr }
            return getLink(deepFunc)
        case _ as IdentifierExprSyntax: return funcExpr
        default: return funcExpr
        }
    }
        
    func translateModifiers(_ viewModifiers: [(String, Syntax)]) -> ([String], [String], [String], [String], [String], [String]) {
        let reversedModifiers = viewModifiers.reversed()
        var borders = [(String, Syntax)]()
        var modifiers = [(String, Syntax)]()
        var navigations = [(String, Syntax)]()
        var scaleFits = [(String, Syntax)]()
        var styles = [(String, Syntax)]()
        var tints = [(String, Syntax)]()
                                
        reversedModifiers.forEach { viewModifier in
            if ViewModifiers.borders.contains(viewModifier.0) { borders.append(viewModifier) }
            if ViewModifiers.modifiers.contains(viewModifier.0) { modifiers.append(viewModifier) }
            if ViewModifiers.navigations.contains(viewModifier.0) { navigations.append(viewModifier) }
            if ViewModifiers.scaleFits.contains(viewModifier.0) { scaleFits.append(viewModifier) }
            if ViewModifiers.styles.contains(viewModifier.0) { styles.append(viewModifier) }
            if ViewModifiers.tints.contains(viewModifier.0) { tints.append(viewModifier) }
        }
                                        
        return (borders.map({ translateModifier($0) }), modifiers.map({ translateModifier($0) }), navigations.map({ translateModifier($0) }), scaleFits.map({ translateModifier($0) }), styles.map({ translateModifier($0) }), tints.map({ translateModifier($0) }))
    }
    
    func translateImage(_ viewBody: FunctionCallExprSyntax, _ modifiers: [(String, Syntax)], _ depth: Int) -> String {
        var s = ""
        var imageName = ""
        var icon = false
        viewBody.argumentList.forEach { argument in
            if let name = (argument.expression as? StringLiteralExprSyntax)?.segments.withoutTrivia().description {
                icon = argument.label?.text == "systemName"
                imageName = name
            } else {
                imageName = argument.expression.description
            }

        }
        let (borders, translatedModifiers, _, scaleFits, _, tints) = translateModifiers(modifiers)
        if !icon {
            s += "Image(name = \(imageName)"
        } else {
            /// Icon
            s += "Icon(Icons.Rounded.\(imageName.components(separatedBy: ".")[0].capitalizingFirstLetter())"
            s += tints.isEmpty ? "" : ", \(tints.joined(separator: " + ").replacingOccurrences(of: "color", with: "tint"))"
            s += ")"
            return s
        }
        var newDepth = depth
        if !borders.isEmpty {
            newDepth += 1
            let shape = translatedModifiers.first(where: { $0.starts(with: "Modifier.clip") })?.components(separatedBy: "(")[1].components(separatedBy: ")")[0]
            s = "Box(\(shape != nil ? "shape = \(shape!), " : "")border = \(borders.joined(separator: " + ")))\(translatedModifiers.isEmpty ? "" : ", modifier = \(translatedModifiers.joined(separator: " + "))")) {\n" + tab(depth) + s
        }
        if borders.isEmpty {
            s += translatedModifiers.isEmpty ? "" : ", modifier = \(translatedModifiers.joined(separator: " + "))"
        }
        s += scaleFits.isEmpty ? "" : ", scaleFit = \(scaleFits.joined(separator: " + "))"
        s += ")"
        if !borders.isEmpty {
            s += newLine() + tab(newDepth - 2) + "}"
        }
        return s
    }
    
    func translateForEach(_ viewBody: FunctionCallExprSyntax, _ depth: Int) -> String {
        guard let closure = viewBody.trailingClosure else { return "" }
        var s = ""
        var isFirsArgument = true
        viewBody.argumentList.forEach { argument in
            if isFirsArgument {
                s += argument.expression.description
                isFirsArgument = false
            }
        }
        s += ".forEach { \(closure.signature?.input?.description ?? "_ ")->\n"
        closure.statements.forEach { statement in
            s += tab(depth) + translateView(statement, depth + 1)
        }
        s += newLine() + tab(depth - 1) + "}"
        return s
    }
    
    func translateCustom(_ funcExpr: FunctionCallExprSyntax, _ idenExpr: IdentifierExprSyntax, _ modifiers: [(String, Syntax)], _ depth: Int) -> String {
        var s = ""
        s += idenExpr.identifier.text
        s += "("
        s += funcExpr.argumentList.map { argument in
            argument.expression.description.replacingOccurrences(of: "$0", with: "it").replacingOccurrences(of: "!", with: "!!")
        }.joined(separator: ", ")
        s += ")"
        var (_, translatedModifiers, _, _, _, _) = translateModifiers(modifiers)
        translatedModifiers.append("Modifier.fillMaxWidth()")
        
        s = "Box(modifier = \(translatedModifiers.joined(separator: " + ")), gravity = ContentGravity.Center) {" + newLine() + tab(depth) + s + newLine() + tab(depth - 1) + "}"
        return s
    }
    
    func translateButton(_ funcExpr: FunctionCallExprSyntax, _ depth: Int) -> String {
        var s = ""
        guard let closure = funcExpr.trailingClosure else { return s }
        if let actionExpr = funcExpr.argumentList.first(where: { $0.label?.text == "action" }), let action = actionExpr.expression as? ClosureExprSyntax {
            s += "Clickable(onClick = {" + newLine()
            s += translateSwift(action.statements, depth)
            s += tab(depth - 1) + "}) {" + newLine() + tab(depth)
            closure.statements.forEach { statement in
                s += translateView(statement, depth + 1)
            }
            s += newLine() + tab(depth - 1) + "}"
        } else {
            s += "Button(onClick = {" + newLine()
            s += translateSwift(closure.statements, depth)
            s += tab(depth - 1) + "}) {" + newLine() + tab(depth)
            s += "Text(text = "
            funcExpr.argumentList.forEach { argument in
                guard let string = argument.expression as? StringLiteralExprSyntax else { return }
                s += translate(string)
            }
            s += ")" + newLine() + tab(depth - 1) + "}"
        }
        return s
    }
    
    func translateSwift(_ code: CodeBlockItemListSyntax, _ depth: Int) -> String {
        var s = ""
        code.forEach { statement in
            if let seq = statement.item as? SequenceExprSyntax {
                s += tab(depth)
                seq.elements.forEach { expr in
                    switch expr {
                    case let member as MemberAccessExprSyntax: s += translateMember(member)
                    case let biOp as BinaryOperatorExprSyntax: s += " \(biOp.withoutTrivia()) "
                    case let intLit as IntegerLiteralExprSyntax: s += intLit.withoutTrivia().description
                    default : break
                    }
                }
                s += "\n"
            } else {
                s += tab(depth)
                KotlinTokenizer().translate(content: statement.description).tokens?.forEach({ token in
                    s += token.value
                })
            }
        }
        return s
    }
    
    func translateMember(_ memAccExpr: MemberAccessExprSyntax) -> String {
        return "\(memAccExpr.name.withoutTrivia()).value"
    }
    
    func translateText(_ funcExpr: FunctionCallExprSyntax, _ modifiers: [(String, Syntax)], _ depth: Int) -> String {
        var s = ""
        s += "Text(text = "
        funcExpr.argumentList.forEach { argument in
            if let string = argument.expression as? StringLiteralExprSyntax {
                s += translate(string)
            } else {
                s += argument.expression.description
            }
        }
        var (_, translatedModifiers, _, _, styles, _) = translateModifiers(modifiers)
        if !translatedModifiers.contains(where: { $0.contains("Modifier.padding") }) {
            translatedModifiers.append("Modifier.padding(5.dp)")
        }
        s += ", modifier = \(translatedModifiers.joined(separator: " + "))"
        s += styles.isEmpty ? "" : ", style = TextStyle(\(styles.joined(separator: ", ")))"
        s += ")"
        return s
    }
    
    func translateFont(_ arguments: FunctionCallArgumentListSyntax) -> String {
        var textSize: Double = 3
        var headline = false
        arguments.forEach { argument in
            guard let font = (argument.expression as? MemberAccessExprSyntax)?.name.text else { return }
            switch font {
            case "headline": headline = true
            case "caption": textSize = 2.5
            case "largeTitle": textSize = 5
            case "title": textSize = 4
            case "subheadline": textSize = 3
            case "callout": textSize = 2.5
            case "footnote": textSize = 2.5
            case "body": textSize = 2.5
            default: break
            }
        }
        return headline ? "fontWeight = FontWeight.Bold" : "fontSize = TextUnit.Em(\(textSize))"
    }
    
    func translate(_ string: StringLiteralExprSyntax) -> String {
        var s = "\""
        string.segments.forEach { segment in
            if let interPolatedString = segment as? ExpressionSegmentSyntax {
                interPolatedString.expressions.forEach { expr in
                    if expr.expression.description.contains("%") { return }
                    s += "${"
                    s += "\(expr.expression.description).value"
                    s += "}"
                }
            } else {
                s += segment.description
            }
        }
        s += "\""
        return s
    }
    
    func translateStack(_ stackType: StackType, _ funcExpr: FunctionCallExprSyntax, _ modifiers: [(String, Syntax)], _ depth: Int) -> String {
        guard let closureExpr = funcExpr.trailingClosure else { return "" }
        var s = stackType.translation
        var allModifiers = modifiers
        funcExpr.argumentList.reversed().forEach { argument in
            guard let name = argument.label?.text else { return }
            allModifiers.append((name, argument.expression))
        }
        var (borders, translatedModifiers, _, _, _, _) = translateModifiers(allModifiers)
        translatedModifiers.append("Modifier.fillMaxSize()")
        if !translatedModifiers.contains(where: { $0.contains("wrapContentSize") }) {
            translatedModifiers.append("Modifier.wrapContentSize(Alignment.Center\(stackType == .HStack ? "Start" : ""))")
        }
        var newDepth = depth
        if !borders.isEmpty {
            newDepth += 1
            s = "Box(border = \(borders.joined(separator: " + "))\(translatedModifiers.isEmpty ? "" : ", modifier = \(translatedModifiers.joined(separator: " + "))")) {\n" + tab(depth) + s
        }
        s += "("
        if borders.isEmpty {
            s += translatedModifiers.isEmpty ? "" : "modifier = \(translatedModifiers.joined(separator: " + ")), "
        }
        s += "arrangement = Arrangement.Center)"
        s += " {\n"
        closureExpr.statements.forEach { view in
            s += tab(newDepth) + translateView(view, newDepth + 1) + newLine()
        }
        s += tab(newDepth - 1) + "}"
        if !borders.isEmpty {
            s += newLine() + tab(newDepth - 2) + "}"
        }
        return s
    }
    
    func getView(_ bindings: PatternBindingListSyntax) -> CodeBlockSyntax? {
        var codeSyntax: CodeBlockSyntax? = nil
        bindings.forEach { binding in
            codeSyntax = binding.accessor as? CodeBlockSyntax
        }
        return codeSyntax
    }
    
    func value(_ bindings: PatternBindingListSyntax) -> String {
        var s = ""
        bindings.forEach { pattern in
            s += pattern.initializer?.value.description ?? pattern.description
        }
        return s
    }
    
    func translateToKotlin(_ decl: Syntax) -> String {
        var s = "\n"
        let result = KotlinTokenizer().translate(content: decl.description)
        result.tokens?.forEach({ token in
            s += token.value
        })
        return s
    }
    
    func tab(_ count: Int = 1) -> String {
        String(repeating: "\t", count: count)
    }
    
    func newLine(_ count: Int = 1) -> String {
        String(repeating: "\n", count: count)
    }
    
}

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}
