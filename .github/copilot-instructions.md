---
aplyTo: "**/*.swift"
---
## Naming
- Use camel case
- Use uppercase for types (and protocols), lowercase for everything else
- Prefer clarity over brevity
- Avoid abbreviations
- Include all the words needed to avoid ambiguity
- Use names based on roles, not types. In case of similar properties with different type (e.g inside a function), we may use greetingStr or greetingAttrStr.
- Prefer to name the first parameter instead of including its name in the method name (exception: delegate parameter as in the following rule)
- Compensate for weak type information to clarify a parameter’s role
- Begin factory methods with make (or create, or newElement). If in the class itself, make() suffices. If in a factory, e.g BikePartsFactory, we can add makeFrontWheel(), makeRearWheel() etc, where FrontWheel and RearWheel are classes
- Name functions and methods according to their side-effects
    - those without side-effects should read as noun phrases, e.g. x.distance(to: y), i.successor()
    - those with side-effects should read as imperative verb phrases, e.g., print(x), x.sort(), x.append(y)
    - name Mutating/nonmutating method pairs consistently. A mutating method will often have a nonmutating variant with similar semantics, but that returns a new value rather than updating an instance in-place
    - when the operation is naturally described by a verb, use the verb’s imperative for the mutating method and apply the “ed” or “ing” suffix to name its nonmutating counterpart
    - when the operation is naturally described by a noun, use the noun for the nonmutating method and apply the “form” prefix to name its mutating counterpart
- Uses of Boolean methods and properties should read as assertions about the receiver when the use is nonmutating, e.g. x.isEmpty, line1.intersects(line2)
- Protocols that describe what something is should read as nouns (e.g. Collection, CollectionProtocol)
- Protocols that describe a capability should be named using the suffixes able, ible, or ing (e.g. Equatable, ProgressReporting)
- The names of other types, variables, and constants should read as nouns
- Label tuple members and name closure parameters

## Documentation
- Document public APIs with `///` doc comments.
- Annotate deprecated APIs with `@available`.

# Error handling
- Use `throws` and `do-try-catch` for error propagation.
- Define custom `Error` types with descriptive cases.

## Type inference and Type declaration
- Take advantage of type inference when declaring new variables or properties. Type inference is generally fast enough for simple expressions.
- You may use explicit types for complex expressions, though, if you feel it improves readability or helps Xcode figure out the types.
- Prefer the shortcut versions of type declarations over the full generics syntax.

## Code organization
- Use extensions to organize your code into logical blocks of functionality. Each extension should be set off with a `// MARK: - comment` to keep things well-organized.
- Prefer adding a separate extension per protocol conformance
- Add lifecycle methods with the order they are naturally called
- Prefer to add the rest methods with the order they are called within a classes
- Import only the modules a source file requires. For example, don't import UIKit when importing Foundation will suffice. Likewise, don't import Foundation if you must import UIKit
- sort imports alphabetically.

## Interface Segregation Principle
- Apply Interface Segregation Principle when creating protocols

## Spacing
- Indent using 4 spaces
- There should be one blank line between methods and up to one blank line between type declarations
- There should be no blank lines before a closing brace
- Colons always have no space on the left and one space on the right. Exceptions are the ternary operator ? : , empty dictionary [:] and #selector syntax addTarget(_:action:)
- For closures with multiple parameters, there should be a single space after every comma. (example: `{ _, value, otherValue in ... }`)

## Comments
- When they are needed, use comments to explain why a particular piece of code does something. Comments must be kept up-to-date or deleted.
- Avoid block comments inline with code, as the code should be as self-documenting as possible. Exception: This does not apply to those comments used to generate documentation.
- Avoid the use of C-style comments (/* ... */). Prefer the use of double- or triple-slash.

## Classes and Structs
- Structs have value semantics. Use structs for things that do not have an identity. An array that contains [a, b, c] is really the same as another array that contains [a, b, c] and they are completely interchangeable. It doesn't matter whether you use the first array or the second, because they represent the exact same thing. That's why arrays are structs.
- Classes have reference semantics. Use classes for things that do have an identity or a specific life cycle. You would model a person as a class because two person objects are two different things. Just because two people have the same name and birthdate, doesn't mean they are the same person. But the person's birthdate would be a struct because a date of 3 March 1950 is the same as any other date object for 3 March 1950. The date itself doesn't have an identity.

## Redundants
- Don't add modifiers such as internal when they're already the default. Similarly, don't repeat the access modifier when overriding a method.
- Avoid using self since Swift does not require it to access an object's properties or invoke its methods.
- In contrast with switch statements in C and Objective-C, switch statements in Swift don’t fall through the bottom of each case and into the next one by default. Avoid using break when not needed
- If a computed property is read-only, omit the get clause. The get clause is required only when a set clause is provided
- Use implicit returns where possible
- Swift does not require a semicolon after each statement in your code. They are only required if you wish to combine multiple statements on a single line, which must be avoided since it reduces readability.
- Parentheses around conditionals are not required and should be omitted. In larger expressions, optional parentheses can sometimes make code read more clearly.

## Access control and Scope
- Use private and fileprivate appropriately to add clarity and promote encapsulation. Prefer private to fileprivate; use fileprivate only when there is a reason.
- Use private variables. If access is needed but edit should not be possible from outsiders, use private(set).
- Likewise consider if the use of open, public, and internal(implicit internal) is needed.
- Use access control as the leading property specifier. The only things that should come before access control are the static specifier or attributes such as @IBAction, @IBOutlet and @discardableResult.
- Prefer using final when a derived class is unneeded.
- For outlets, prefer using private or private(set) scope, and always create/convert them to both weak and optional.

## Function declarations and Calls
- Keep short function declarations on one line including the opening brace. For functions with long signatures, place each parameter in a new line and add an extra indent on subsequent lines.
- Mirror the style of function declarations at call sites.
- Chained methods using trailing closures should be clear and easy to read in context. Decisions on spacing, line breaks, and when to use named versus anonymous arguments is left to the discretion of the author

## Optionals
- Declare variables and function return types as optional with ? where a nil value is acceptable.
- Do not force unwrap. Also do not access an array's item based on index, e.g array[5], but rather use our "exist" subscript,  subscript (exist index: Index) -> Iterator.Element?
- When accessing an optional value, use optional chaining if there is no need for a safe unwrap (since a safe unwrap will create another temporary property)
- For optional binding, shadow the original name whenever possible rather than using names like unwrappedView or actualLabel.

## Falling guards and Golden parentheses
- Guard statements are required to exit in some way. Generally, this should be simple one line statement such as return, throw, break, continue, and fatalError(). Large code blocks should be avoided. If cleanup code is required for multiple exit points, consider using a defer block to avoid cleanup code duplication.
- An empty fail statement (e.g else { return }) after a guard statement is a missed opportunity. Apart from code cleanup, it might be a suitable place trigger a UIAlert, and generally handle an unexpected situation.
- If we assume a guard should never fail, add an assertion in the else block. It might prove useful in the long run.
- When coding with conditionals, the left-hand margin of the code should be the "golden" or "happy" path. That is, don't nest if statements. Multiple return statements are OK. The guard statement is built for this
- When multiple optionals are unwrapped either with guard or if let, minimize nesting by using the compound version when possible. In the compound version, place the guard on its own line, then indent each condition on its own line. The else clause is indented to match the guard itself.
- Also available from Swift 5.7 (Swift proposal SE-0345), there is a new shorthand syntax for unwrapping optionals into shadowed variables of the same name using if let and guard let.

## Memory management
- Code (even non-production) must not create retain cycles. 
- Analyze your object graph and prevent strong cycles with weak references (e.g mandatory in delegation).
- When in a block that will be executed asynchronously, do not use a strong reference of self (e.g self. ) without first safe unwrapping an optional reference to self. Use the suggested swift 4.2+ approach:
- Do not use unowned self since it may not increase the reference counter (ARC), but is practically equal to a force unwrap on an optional.

## General good practices
- Write unit tests for all your code
- Avoid using static properties and functions if they are not needed
- Avoid nested if statements
- Do not use delays unless there is a reason for it
- Folder names should not contain spaces.
- Always inject the dependencies of a class in the initializer. Avoid using singletons and static properties.
- Avoid using global variables
- Avoid using global functions
- Avoid using global constants
- Add the prefix any when using plain protocol names in type context.
- Do not add print statements.
