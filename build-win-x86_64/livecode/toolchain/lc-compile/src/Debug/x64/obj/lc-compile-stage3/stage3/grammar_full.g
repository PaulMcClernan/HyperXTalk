'module' grammar_full

'use'
    support
    types
    bind
    check
    generate
    syntax

--------------------------------------------------------------------------------

'root'
    Parse(-> Modules)
    (|
        ErrorsDidOccur()
    ||
        IsDependencyCompile()
        
        DependStart()

        -- First generate the mapping between module name and source-file(s)
        Depend_GenerateMapping(Modules)
        
        -- Now generate the direct dependencies for each module
        Depend_GenerateDependencies(Modules)
        
        DependFinish()
    ||
        Compile(Modules)
    |)

---------

'action' Depend_GenerateMapping(MODULELIST)

    'rule' Depend_GenerateMapping(modulelist(module(Position, Kind, Name, _), Rest)):
    	GetQualifiedName(Name -> ModuleName)
        GetFilenameOfPosition(Position -> Filename)
        DependDefineMapping(ModuleName, Filename)
        Depend_GenerateMapping(Rest)
        
    'rule' Depend_GenerateMapping(nil):
        -- do nothing
        
'action' Depend_GenerateDependencies(MODULELIST)

    'rule' Depend_GenerateDependencies(modulelist(module(_, _, Name, Definitions), Rest)):
    	GetQualifiedName(Name -> ModuleName)
        Depend_GenerateDependenciesForModule(ModuleName, Definitions)
        Depend_GenerateDependencies(Rest)

    'rule' Depend_GenerateDependencies(nil):
        -- do nothing

'action' Depend_GenerateDependenciesForModule(NAME, DEFINITION)

    'rule' Depend_GenerateDependenciesForModule(ModuleName, sequence(Left, Right)):
        Depend_GenerateDependenciesForModule(ModuleName, Left)
        Depend_GenerateDependenciesForModule(ModuleName, Right)

    'rule' Depend_GenerateDependenciesForModule(ModuleName, import(_, Name)):
        GetQualifiedName(Name -> DependencyName)
        DependDefineDependency(ModuleName, DependencyName)

    'rule' Depend_GenerateDependenciesForModule(ModuleName, _):
        -- do nothing

---------

'action' Compile(MODULELIST)

    'rule' Compile(Modules):
        InitializeBind
        BindModules(Modules, Modules)
        (|
            ErrorsDidOccur()
        ||
            CheckModules(Modules)
            (|
                ErrorsDidOccur()
            ||
                (|
                    IsBootstrapCompile()
                    InitializeSyntax
                    GenerateSyntaxForModules(Modules)
                    (|
                        ErrorsDidOccur()
                    ||
                        GenerateSyntaxRules()
                        GenerateModules(Modules)
                    |)
                ||
					GenerateModules(Modules)
                |)
            |)
        |)

'action' BindModules(MODULELIST, MODULELIST)

    'rule' BindModules(modulelist(Head, Tail), Imports):
        (|
            Head'Kind -> import
        ||
            Bind(Head, Imports)
        |)
        BindModules(Tail, Imports)
        
    'rule' BindModules(nil, _):
        -- empty

'action' CheckModules(MODULELIST)

    'rule' CheckModules(modulelist(Head, Tail)):
        (|
            Head'Kind -> import
        ||
            Check(Head)
        |)
        CheckModules(Tail)
        
    'rule' CheckModules(nil):
        -- empty
        
'action' GenerateSyntaxForModules(MODULELIST)

    'rule' GenerateSyntaxForModules(modulelist(Head, Tail)):
        (|
            Head'Kind -> import
        ||
            GenerateSyntax(Head)
        |)
        GenerateSyntaxForModules(Tail)

    'rule' GenerateSyntaxForModules(nil):
        -- empty

--------------------------------------------------------------------------------

'nonterm' Parse(-> MODULELIST)

    'rule' Parse(-> Modules):
        ModuleList(-> Modules)

--------------------------------------------------------------------------------
-- Module Syntax
--------------------------------------------------------------------------------

'nonterm' ModuleList(-> MODULELIST)

    'rule' ModuleList(-> modulelist(Head, Tail)):
        Module(-> Head)
        NEXT_UNIT
        ModuleList(-> Tail)
        
    'rule' ModuleList(-> modulelist(Head, nil)):
        Module(-> Head)

'nonterm' Module(-> MODULE)

    'rule' Module(-> module(Position, module, Name, Definitions)):
        OptionalSeparator
        "module" @(-> Position) QualifiedId(-> Name) Separator
        Definitions(-> Definitions)
        "end" "module" OptionalSeparator
        END_OF_UNIT
		GetQualifiedName(Name -> NameName)
        GetStringOfNameLiteral(NameName -> NameString)
		AddImportedModuleName(NameString)

    'rule' Module(-> module(Position, widget, Name, Definitions)):
        OptionalSeparator
        "widget" @(-> Position) QualifiedId(-> Name) Separator
        Definitions(-> Definitions)
        "end" "widget" OptionalSeparator
        END_OF_UNIT

    'rule' Module(-> module(Position, library, Name, Definitions)):
        OptionalSeparator
        "library" @(-> Position) QualifiedId(-> Name) Separator
        Definitions(-> Definitions)
        "end" "library" OptionalSeparator
        END_OF_UNIT

    'rule' Module(-> module(Position, import, Name, Definitions)):
        OptionalSeparator
        "import" "module" @(-> Position) QualifiedId(-> Name) Separator
        ImportDefinitions(-> Definitions)
        "end" "module" OptionalSeparator
        END_OF_UNIT

'nonterm' ImportDefinitions(-> DEFINITION)

    'rule' ImportDefinitions(-> sequence(Left, Right)):
        ImportDefinition(-> Left) Separator
        ImportDefinitions(-> Right)
        
    'rule' ImportDefinitions(-> nil):
        -- done!
        
'nonterm' ImportDefinition(-> DEFINITION)

    'rule' ImportDefinition(-> Import):
        Import(-> Import)

    'rule' ImportDefinition(-> type(Position, public, Id, foreign(Position, ""))):
        "foreign" @(-> Position) "type" Identifier(-> Id)
    
    'rule' ImportDefinition(-> type(Position, public, Id, handler(Position, normal, Signature))):
        "handler" @(-> Position) "type" Identifier(-> Id) Signature(-> Signature)

    'rule' ImportDefinition(-> type(Position, public, Id, handler(Position, foreign, Signature))):
        "foreign" @(-> Position) "handler" "type" Identifier(-> Id) Signature(-> Signature)

    'rule' ImportDefinition(-> type(Position, public, Id, record(Position, Fields))):
        "record" @(-> Position) "type" Identifier(-> Id) Separator
            RecordFields(-> Fields)
        "end" "type"

    'rule' ImportDefinition(-> type(Position, public, Id, Type)):
        "type" @(-> Position) Identifier(-> Id) "is" Type(-> Type)

    'rule' ImportDefinition(-> constant(Position, public, Id, nil)):
        "constant" @(-> Position) Identifier(-> Id)

    'rule' ImportDefinition(-> variable(Position, public, Id, Type)):
        "variable" @(-> Position) Identifier(-> Id) "as" Type(-> Type)

    'rule' ImportDefinition(-> handler(Position, public, Id, Signature, nil, nil)):
        "handler" @(-> Position) Identifier(-> Id) Signature(-> Signature)

    'rule' ImportDefinition(-> unsafe(Position, handler(Position, public, Id, Signature, nil, nil))):
        "unsafe" "handler" @(-> Position) Identifier(-> Id) Signature(-> Signature)

    'rule' ImportDefinition(-> foreignhandler(Position, public, Id, Signature, "")):
        "foreign" "handler" @(-> Position) Identifier(-> Id) Signature(-> Signature)

--------------------------------------------------------------------------------
-- Metadata Syntax
--------------------------------------------------------------------------------

'nonterm' Metadata(-> DEFINITION)

    'rule' Metadata(-> metadata(Position, Key, Value)):
        "metadata" @(-> Position) StringOrNameLiteral(-> Key) "is" StringLiteral(-> Value)
        
--------------------------------------------------------------------------------
-- Import Syntax
--------------------------------------------------------------------------------

'nonterm' Import(-> DEFINITION)
    'rule' Import(-> ImportList):
        "use" @(-> Position) IdentifierList(-> Identifiers)
        ExpandImports(Position, Identifiers -> ImportList)

'action' ExpandImports(POS, IDLIST -> DEFINITION)

    'rule' ExpandImports(Position, idlist(Id, nil) -> import(Position, Id)):
    	GetQualifiedName(Id -> Name)
        GetStringOfNameLiteral(Name -> NameString)
        (|
            (|
                -- In bootstrap mode, all modules have to be listed on command line.
                IsBootstrapCompile()
			||
                AddImportedModuleFile(NameString)
            |)
        ||
            (|
                IsDependencyCompile()
            ||
                Error_UnableToFindImportedModule(Position, Name)
            |)
        |)

    'rule' ExpandImports(Position, idlist(Id, Tail) -> sequence(import(Position, Id), ExpandedTail)):
        ExpandImports(Position, Tail -> ExpandedTail)

--------------------------------------------------------------------------------
-- Definitions Syntax
--------------------------------------------------------------------------------

'nonterm' Definitions(-> DEFINITION)

    'rule' Definitions(-> sequence(Head, Tail)):
        Definition(-> Head) Separator
        Definitions(-> Tail)
        
    'rule' Definitions(-> nil):
        -- empty
        
'nonterm' Definition(-> DEFINITION)

    'rule' Definition(-> Metadata):
        Metadata(-> Metadata)

    'rule' Definition(-> Import):
        Import(-> Import)
        
    'rule' Definition(-> Constant):
        ConstantDefinition(-> Constant)
        
    'rule' Definition(-> Type):
        TypeDefinition(-> Type)

    'rule' Definition(-> Variable):
        VariableDefinition(-> Variable)

    'rule' Definition(-> Handler):
        HandlerDefinition(-> Handler)

    'rule' Definition(-> Property):
        PropertyDefinition(-> Property)

    'rule' Definition(-> Event):
        EventDefinition(-> Event)
        
    'rule' Definition(-> Syntax)
        SyntaxDefinition(-> Syntax)

---------- Constant

'nonterm' ConstantDefinition(-> DEFINITION)

    'rule' ConstantDefinition(-> constant(Position, Access, Name, Value)):
        Access(-> Access) "constant" @(-> Position) Identifier(-> Name) "is" Expression(-> Value)

'nonterm' Access(-> ACCESS)

    'rule' Access(-> inferred):
        -- empty

    'rule' Access(-> public):
        "public"
        
    'rule' Access(-> protected):
        "protected"
        
    'rule' Access(-> private):
        "private"

---------- Variable

'nonterm' VariableDefinition(-> DEFINITION)

    'rule' VariableDefinition(-> variable(Position, Access, Name, Type)):
        Access(-> Access) "variable" @(-> Position) Identifier(-> Name) OptionalTypeClause(-> Type)
        
'nonterm' OptionalTypeClause(-> TYPE)

    'rule' OptionalTypeClause(-> Type):
        "as" Type(-> Type)
        
    'rule' OptionalTypeClause(-> unspecified):
        @(-> Position)

---------- Type

'nonterm' TypeDefinition(-> DEFINITION)

    'rule' TypeDefinition(-> type(Position, Access, Name, Type)):
        Access(-> Access) "type" @(-> Position) Identifier(-> Name) "is" Type(-> Type)
    
    'rule' TypeDefinition(-> type(Position, Access, Name, foreign(Position, Binding))):
        Access(-> Access) "foreign" @(-> Position) "type" Identifier(-> Name) "binds" "to" StringLiteral(-> Binding)
        
    'rule' TypeDefinition(-> type(Position, Access, Name, record(Position, Fields))):
        Access(-> Access) "record" @(-> Position) "type" Identifier(-> Name) Separator
            RecordFields(-> Fields)
        "end" "type"
        
    'rule' TypeDefinition(-> type(Position, Access, Name, enum(Position, Base, Fields))):
        Access(-> Access) "enum" @(-> Position) "type" Identifier(-> Name) OptionalBaseType(-> Base) Separator
            EnumFields(-> Fields)
        "end" "type"
        
    'rule' TypeDefinition(-> type(Position, Access, Name, handler(Position, normal, Signature))):
        Access(-> Access) "handler" @(-> Position) "type" Identifier(-> Name) Signature(-> Signature)

    'rule' TypeDefinition(-> type(Position, Access, Name, handler(Position, foreign, Signature))):
        Access(-> Access) "foreign" @(-> Position) "handler" "type" Identifier(-> Name) Signature(-> Signature)

--

'nonterm' OptionalBaseType(-> TYPE)

    'rule' OptionalBaseType(-> BaseType):
        "based" "on" Type(-> BaseType)
        
    'rule' OptionalBaseType(-> undefined(Position)):
        @(-> Position)

--

'nonterm' TypeFields(-> FIELDLIST)

    'rule' TypeFields(-> fieldlist(Head, Rest)):
        TypeField(-> Head) Separator
        TypeFields(-> Rest)
        
    'rule' TypeFields(-> nil):
        -- nothing

'nonterm' TypeField(-> FIELD)

    'rule' TypeField(-> action(Position, Name, Handler)):
        Identifier(-> Name) @(-> Position) "is" Identifier(-> Handler)

--

'nonterm' RecordFields(-> FIELDLIST)

    'rule' RecordFields(-> fieldlist(Head, Rest)):
        RecordField(-> Head) Separator
        RecordFields(-> Rest)
        
    'rule' RecordFields(-> nil):
        -- nothing

'nonterm' RecordField(-> FIELD)

    'rule' RecordField(-> slot(Position, Name, Type)):
        Identifier(-> Name) @(-> Position) OptionalTypeClause(-> Type)
        
    'rule' RecordField(-> slot(Position, Name, Type)):
        StringyIdentifier(-> Name) @(-> Position) OptionalTypeClause(-> Type)

--

'nonterm' EnumFields(-> FIELDLIST)

    'rule' EnumFields(-> fieldlist(Head, Rest)):
        EnumField(-> Head) Separator
        EnumFields(-> Rest)
        
    'rule' EnumFields(-> nil):
        -- nothing

'nonterm' EnumField(-> FIELD)

    'rule' EnumField(-> element(Position, Name)):
        Identifier(-> Name) @(-> Position)

---------- Handler

'nonterm' HandlerDefinition(-> DEFINITION)

    'rule' HandlerDefinition(-> handler(Position, Access, Name, Signature, nil, Body)):
        Access(-> Access) "handler" @(-> Position) Identifier(-> Name) Signature(-> Signature) Separator
            Statements(-> Body)
        "end" "handler"

    'rule' HandlerDefinition(-> unsafe(Position, handler(Position, Access, Name, Signature, nil, Body))):
        Access(-> Access) "unsafe" "handler" @(-> Position) Identifier(-> Name) Signature(-> Signature) Separator
            Statements(-> Body)
        "end" "handler"

	'rule' HandlerDefinition(-> foreignhandler(Position, Access, Name, Signature, Binding)):
		Access(-> Access) "__safe" "foreign" "handler" @(-> Position) Identifier(-> Name) Signature(-> Signature) "binds" "to" StringLiteral(-> Binding)

    'rule' HandlerDefinition(-> unsafe(Position, foreignhandler(Position, Access, Name, Signature, Binding))):
        Access(-> Access) "foreign" "handler" @(-> Position) Identifier(-> Name) Signature(-> Signature) "binds" "to" StringLiteral(-> Binding)

'nonterm' Signature(-> SIGNATURE)

    'rule' Signature(-> signature(Parameters, Result)):
        "(" OptionalParameterList(-> Parameters) ")" OptionalReturnsClause(-> Result)

'nonterm' OptionalReturnsClause(-> TYPE)

    'rule' OptionalReturnsClause(-> Type)
        "returns" @(-> Position) Type(-> Type)

    'rule' OptionalReturnsClause(-> unspecified)
        @(-> Position)

'nonterm' OptionalParameterList(-> PARAMETERLIST)

    'rule' OptionalParameterList(-> List):
        ParameterList(-> List)
        
    'rule' OptionalParameterList(-> nil):
        -- empty

'nonterm' ParameterList(-> PARAMETERLIST)

    'rule' ParameterList(-> parameterlist(Head, Tail)):
        Parameter(-> Head) "," ParameterList(-> Tail)
        
    'rule' ParameterList(-> parameterlist(Head, nil)):
        Parameter(-> Head)

'nonterm' Parameter(-> PARAMETER)

    'rule' Parameter(-> parameter(Position, Mode, Name, Type)):
        Mode(-> Mode) @(-> Position) Identifier(-> Name) OptionalTypeClause(-> Type)

    'rule' Parameter(-> parameter(Position, in, Name, Type)):
        Identifier(-> Name) @(-> Position) OptionalTypeClause(-> Type)

    'rule' Parameter(-> parameter(Position, variadic, Name, unspecified)):
        "..." @(-> Position)
        MakeNameLiteral("" -> Identifier)
		AssignId(Position, Identifier, nil -> Name)
        
'nonterm' Mode(-> MODE)

    'rule' Mode(-> in):
        "in"

    'rule' Mode(-> out):
        "out"

    'rule' Mode(-> inout):
        "inout"

---------- Property

'nonterm' PropertyDefinition(-> DEFINITION)

    'rule' PropertyDefinition(-> property(Position, public, Name, Getter, Setter)):
        "property" @(-> Position) Identifier(-> Name) "get" Identifier(-> Getter) OptionalSetClause(-> Setter)

    'rule' PropertyDefinition(-> property(Position, public, Name, Getter, Setter)):
        "property" @(-> Position) StringyIdentifier(-> Name) "get" Identifier(-> Getter) OptionalSetClause(-> Setter)

'nonterm' OptionalSetClause(-> OPTIONALID)

    'rule' OptionalSetClause(-> id(Setter)):
        "set" Identifier(-> Setter)
        
    'rule' OptionalSetClause(-> nil):
        -- nothing

---------- Event

'nonterm' EventDefinition(-> DEFINITION)

    'rule' EventDefinition(-> event(Position, public, Name, Signature)):
        "event" @(-> Position) Identifier(-> Name) Signature(-> Signature)

---------- Syntax

'nonterm' SyntaxDefinition(-> DEFINITION)

    'rule' SyntaxDefinition(-> syntax(Position, public, Name, Class, Warnings, Syntax, Methods)):
        "syntax" @(-> Position) Identifier(-> Name) SyntaxClass(-> Class) Separator
            SyntaxWarnings(-> Warnings)
            Syntax(-> Syntax) Separator
        "begin" Separator
            SyntaxMethods(-> Methods)
        "end" "syntax"
    
'nonterm' SyntaxWarnings(-> SYNTAXWARNING)

    'rule' SyntaxWarnings(-> deprecated(Message)):
        "deprecate" "with" "message" StringLiteral(-> Message) Separator
        
    'rule' SyntaxWarnings(-> nil):
        -- nothing

'nonterm' SyntaxClass(-> SYNTAXCLASS)

    'rule' SyntaxClass(-> statement):
        "is" "statement"

    'rule' SyntaxClass(-> expression):
        "is" "expression"

    'rule' SyntaxClass(-> iterator):
        "is" "iterator"

    'rule' SyntaxClass(-> prefix(Precedence)):
        "is" "prefix" "operator" "with" SyntaxPrecedence(-> Precedence) "precedence"

    'rule' SyntaxClass(-> postfix(Precedence)):
        "is" "postfix" "operator" "with" SyntaxPrecedence(-> Precedence) "precedence"

    'rule' SyntaxClass(-> binary(Assoc, Precedence)):
        "is" SyntaxAssoc(-> Assoc) "binary" "operator" "with" SyntaxPrecedence(-> Precedence) "precedence"

    'rule' SyntaxClass(-> phrase):
        "is" "phrase"

'nonterm' SyntaxAssoc(-> SYNTAXASSOC)

    'rule' SyntaxAssoc(-> neutral):
        "neutral"
        
    'rule' SyntaxAssoc(-> left):
        "left"
        
    'rule' SyntaxAssoc(-> right):
        "right"

'nonterm' SyntaxPrecedence(-> SYNTAXPRECEDENCE)

    'rule' SyntaxPrecedence(-> scoperesolution):
        "scope" "resolution"

    'rule' SyntaxPrecedence(-> functioncall):
        "function" "call"

    'rule' SyntaxPrecedence(-> subscript):
        "subscript"

    'rule' SyntaxPrecedence(-> property):
        "property"

    'rule' SyntaxPrecedence(-> subscriptchunk):
        "subscript chunk"

    'rule' SyntaxPrecedence(-> functionchunk):
        "function chunk"

    'rule' SyntaxPrecedence(-> constructor):
        "constructor"

    'rule' SyntaxPrecedence(-> conversion):
        "conversion"

    'rule' SyntaxPrecedence(-> exponentiation):
        "exponentiation"

    'rule' SyntaxPrecedence(-> modifier):
        "modifier"

    'rule' SyntaxPrecedence(-> multiplication):
        "multiplication"

    'rule' SyntaxPrecedence(-> addition):
        "addition"

    'rule' SyntaxPrecedence(-> bitwiseshift):
        "bitwise shift"

    'rule' SyntaxPrecedence(-> concatenation):
        "concatenation"

    'rule' SyntaxPrecedence(-> comparison):
        "comparison"

    'rule' SyntaxPrecedence(-> classification):
        "classification"

    'rule' SyntaxPrecedence(-> bitwiseand):
        "bitwise and"

    'rule' SyntaxPrecedence(-> bitwisexor):
        "bitwise xor"

    'rule' SyntaxPrecedence(-> bitwiseor):
        "bitwise or"

    'rule' SyntaxPrecedence(-> logicalnot):
        "logical not"

    'rule' SyntaxPrecedence(-> logicaland):
        "logical and"

    'rule' SyntaxPrecedence(-> logicalor):
        "logical or"

    'rule' SyntaxPrecedence(-> sequence):
        "sequence"

'nonterm' SyntaxMethods(-> SYNTAXMETHODLIST)

    'rule' SyntaxMethods(-> methodlist(Head, Tail)):
        SyntaxMethod(-> Head) Separator
        SyntaxMethods(-> Tail)
        
    'rule' SyntaxMethods(-> nil):
        -- empty

'nonterm' SyntaxMethod(-> SYNTAXMETHOD)

    'rule' SyntaxMethod(-> method(Position, Name, Arguments)):
        Identifier(-> Name) @(-> Position) "(" OptionalConstantList(-> Arguments) ")"

--------------------------------------------------------------------------------
-- Type Syntax
--------------------------------------------------------------------------------

'nonterm' Type(-> TYPE)

    'rule' Type(-> named(Position, Name)):
        QualifiedId(-> Name) @(-> Position)
        
    'rule' Type(-> optional(Position, Base)):
        "optional" @(-> Position) Type(-> Base)

    'rule' Type(-> any(Position)):
        "any" @(-> Position)

    'rule' Type(-> boolean(Position)):
        "Boolean" @(-> Position)

    'rule' Type(-> integer(Position)):
        "Integer" @(-> Position)

    'rule' Type(-> real(Position)):
        "Real" @(-> Position)

    'rule' Type(-> number(Position)):
        "Number" @(-> Position)

    'rule' Type(-> string(Position)):
        "String" @(-> Position)

    'rule' Type(-> data(Position)):
        "Data" @(-> Position)

    'rule' Type(-> array(Position)):
        "Array" @(-> Position)

    'rule' Type(-> list(Position, ElementType)):
        "List" @(-> Position) OptionalElementType(-> ElementType)

    'rule' Type(-> undefined(Position)):
        "nothing" @(-> Position)

'nonterm' OptionalElementType(-> TYPE)

    'rule' OptionalElementType(-> Type)
        "of" Type(-> Type)
        
    'rule' OptionalElementType(-> unspecified):
        @(-> Position)

--------------------------------------------------------------------------------
-- Statement Syntax
--------------------------------------------------------------------------------

'nonterm' Statements(-> STATEMENT)

    'rule' Statements(-> sequence(Left, Right)):
        Statement(-> Left) Separator
        Statements(-> Right)
        
    'rule' Statements(-> nil):
        -- empty

'nonterm' Statement(-> STATEMENT)

    'rule' Statement(-> variable(Position, Name, Type)):
        "variable" @(-> Position) Identifier(-> Name) OptionalTypeClause(-> Type)

    'rule' Statement(-> if(Position, Condition, Consequent, Alternate)):
        "if" @(-> Position) Expression(-> Condition) "then" Separator
            Statements(-> Consequent)
        IfStatementElseIfs(-> Alternate)
        "end" "if"
        
    'rule' Statement(-> repeatforever(Position, Body)):
        "repeat" @(-> Position) "forever" Separator
            Statements(-> Body)
        "end" "repeat"

    'rule' Statement(-> repeatcounted(Position, Count, Body)):
        "repeat" @(-> Position) Expression(-> Count) "times" Separator
            Statements(-> Body)
        "end" "repeat"

    'rule' Statement(-> repeatwhile(Position, Condition, Body)):
        "repeat" @(-> Position) "while" Expression(-> Condition) Separator
            Statements(-> Body)
        "end" "repeat"

    'rule' Statement(-> repeatuntil(Position, Condition, Body)):
        "repeat" @(-> Position) "until" Expression(-> Condition) Separator
            Statements(-> Body)
        "end" "repeat"

    'rule' Statement(-> repeatupto(Position, Slot, Start, Finish, Step, Body)):
        "repeat" @(-> Position) "with" Identifier(-> Slot) "from" Expression(-> Start) "up" "to" Expression(-> Finish) RepeatStatementOptionalBy(-> Step) Separator
            Statements(-> Body)
        "end" "repeat"

    'rule' Statement(-> repeatdownto(Position, Slot, Start, Finish, Step, Body)):
        "repeat" @(-> Position) "with" Identifier(-> Slot) "from" Expression(-> Start) "down" "to" Expression(-> Finish) RepeatStatementOptionalBy(-> Step) Separator
            Statements(-> Body)
        "end" "repeat"
        
    'rule' Statement(-> repeatforeach(Position, Iterator, Container, Body)):
        "repeat" @(-> Position) "for" "each" CustomIterators(-> Iterator) "in" Expression(-> Container) Separator
            Statements(-> Body)
        "end" "repeat"

    /*'rule' Statement(-> try(Position, Body, Catches, Finally)):
        "try" @(-> Position) Separator
            Statements(-> Body)
        TryStatementCatches(-> Catches)
        TryStatementFinally(-> Finally)
        "end" "try"*/
        
    'rule' Statement(-> throw(Position, Value)):
        "throw" @(-> Position) Expression(-> Value)

    'rule' Statement(-> nextrepeat(Position)):
        "next" @(-> Position) "repeat"

    'rule' Statement(-> exitrepeat(Position)):
        "exit" @(-> Position) "repeat"
        
    'rule' Statement(-> return(Position, nil)):
        "return" @(-> Position)
        
    'rule' Statement(-> return(Position, Value)):
        "return" @(-> Position) Expression(-> Value)
        
    'rule' Statement(-> put(Position, Source, Target)):
        "put" @(-> Position) Expression(-> Source) "into" Expression(-> Target)

    'rule' Statement(-> put(Position, Source, Target)):
        "set" @(-> Position) Expression(-> Target) "to" Expression(-> Source)
        
    'rule' Statement(-> get(Position, Value)):
        "get" @(-> Position) Expression(-> Value)

    'rule' Statement(-> call(Position, Handler, Arguments)):
        QualifiedId(-> Handler) @(-> Position) "(" OptionalExpressionList(-> Arguments) ")"

    'rule' Statement(-> bytecode(Position, Opcodes)):
        "bytecode" @(-> Position) Separator
            Bytecodes(-> Opcodes)
        "end" "bytecode"

    'rule' Statement(-> unsafe(Position, Body)):
        "unsafe" @(-> Position) Separator
            Statements(-> Body)
        "end" "unsafe"

    'rule' Statement(-> postfixinto(Position, Statement, Target)):
        CustomStatements(-> Statement) "into" @(-> Position) Expression(-> Target)

    'rule' Statement(-> Statement):
        CustomStatements(-> Statement)
        
'nonterm' IfStatementElseIfs(-> STATEMENT)

    'rule' IfStatementElseIfs(-> if(Position, Condition, Consequent, Alternate)):
        "else" @(-> Position) "if" Expression(-> Condition) "then" Separator
            Statements(-> Consequent)
        IfStatementElseIfs(-> Alternate)
        
    'rule' IfStatementElseIfs(-> Else):
        "else" @(-> Position) Separator
            Statements(-> Else)
            
    'rule' IfStatementElseIfs(-> nil):
        -- nothing

'nonterm' RepeatStatementOptionalBy(-> EXPRESSION)

    'rule' RepeatStatementOptionalBy(-> By):
        "by" Expression(-> By)
        
    'rule' RepeatStatementOptionalBy(-> nil):
        -- nothing

/*'nonterm' TryStatementCatches(-> STATEMENT)

    'rule' TryStatementCatches(-> catch(Position, Type, Body)):
        "catch" Type(-> Type) Separator
            Statements(-> Body)*/

--------------------------------------------------------------------------------
-- Bytecode Syntax
--------------------------------------------------------------------------------

'nonterm' Bytecodes(-> BYTECODE)

    'rule' Bytecodes(-> sequence(Left, Right)):
        Bytecode(-> Left) Separator
        Bytecodes(-> Right)

    'rule' Bytecodes(-> nil):
        -- empty

'nonterm' Bytecode(-> BYTECODE)

    'rule' Bytecode(-> label(Position, Name)):
        Identifier(-> Name) @(-> Position) ":"

    'rule' Bytecode(-> register(Position, Name, Type)):
        "register" @(-> Position) Identifier(-> Name) OptionalTypeClause(-> Type)

    'rule' Bytecode(-> opcode(Position, Opcode, Arguments)):
        NAME_LITERAL(-> Opcode) @(-> Position) OptionalExpressionList(-> Arguments)

    'rule' Bytecode(-> opcode(Position, Opcode, Arguments)):
        CustomKeywords(-> OpcodeString) @(-> Position) OptionalExpressionList(-> Arguments)
        MakeNameLiteral(OpcodeString -> Opcode)

--------------------------------------------------------------------------------
-- Expression Syntax
--------------------------------------------------------------------------------

'action' ProcessOperatorExpression(-> EXPRESSION)

    'rule' ProcessOperatorExpression(-> invoke(Position, Method, Arguments)):
        PopOperatorExpression(-> Position, MethodIndex, Arity)
        ProcessOperatorExpressionChildren(Arity -> Arguments)
        CustomInvokeLists(MethodIndex -> Method)

    'rule' ProcessOperatorExpression(-> Expr):
        PopOperatorExpressionArgument(-> Expr)
        
'action' ProcessOperatorExpressionChildren(INT -> EXPRESSIONLIST)

    'rule' ProcessOperatorExpressionChildren(Arity -> nil):
        eq(Arity, 0)

    'rule' ProcessOperatorExpressionChildren(Arity -> expressionlist(Head, Tail)):
        ProcessOperatorExpression(-> Head)
        ProcessOperatorExpressionChildren(Arity - 1 -> Tail)

'nonterm' Expression(-> EXPRESSION)

    'rule' Expression(-> logicalor(Position, Left, Right)):
        Expression(-> Left) "or" @(-> Position) AndExpression(-> Right)
        
    'rule' Expression(-> Expr)
        AndExpression(-> Expr)
        
'nonterm' AndExpression(-> EXPRESSION)

    'rule' AndExpression(-> logicaland(Position, Left, Right)):
        AndExpression(-> Left) "and" @(-> Position) NormalExpression(-> Right)
    
    'rule' AndExpression(-> Result):
        NormalExpression(-> Result)
        
'nonterm' NormalExpression(-> EXPRESSION)

    'rule' NormalExpression(-> Result):
        FlatExpression(-> Sentinal)
        ReorderOperatorExpression(Sentinal)
        ProcessOperatorExpression(-> Result)

----------

'action' min(INT, INT -> INT)
    'rule' min(A, B -> A):
        le(A, B)
    'rule' min(A, B -> B):

'nonterm' FlatExpression(-> INT)

    'rule' FlatExpression(-> Sentinal):
        FlatExpressionTerm(-> Sentinal) FlatExpressionBinaryOperator(-> _) FlatExpression(-> _)
        
    'rule' FlatExpression(-> Sentinal):
        FlatExpressionTerm(-> Sentinal)
        
'nonterm' FlatExpressionTerm(-> INT)

    'rule' FlatExpressionTerm(-> Sentinal):
        FlatExpressionPrefixOperators(-> Sentinal1) FlatExpressionOperand(-> Sentinal2) FlatExpressionPostfixOperators(-> _)
        min(Sentinal1, Sentinal2 -> Sentinal)
        
'nonterm' FlatExpressionPrefixOperators(-> INT)

    'rule' FlatExpressionPrefixOperators(-> Sentinal):
        FlatExpressionPrefixOperator(-> Sentinal) FlatExpressionPrefixOperators(-> _)
        
    'rule' FlatExpressionPrefixOperators(-> 10000):
        -- nothing

'nonterm' FlatExpressionPostfixOperators(-> INT)

    'rule' FlatExpressionPostfixOperators(-> Sentinal):
        FlatExpressionPostfixOperator(-> Sentinal) FlatExpressionPostfixOperators(-> _)
        
    'rule' FlatExpressionPostfixOperators(-> 10000):
        -- nothing
        
'nonterm' FlatExpressionPrefixOperator(-> INT)
        
    'rule' FlatExpressionPrefixOperator(-> Sentinal):
        CustomPrefixOperators(-> Sentinal)

'nonterm' FlatExpressionPostfixOperator(-> INT)

    'rule' FlatExpressionPostfixOperator(-> Sentinal):
        CustomPostfixOperators(-> Sentinal)

'nonterm' FlatExpressionBinaryOperator(-> INT)
        
    'rule' FlatExpressionBinaryOperator(-> Sentinal):
        CustomBinaryOperators(-> Sentinal)

'nonterm' FlatExpressionOperand(-> INT)
        
    'rule' FlatExpressionOperand(-> Sentinal)
        TermExpression(-> Term)
        PushOperatorExpressionOperand(Term -> Sentinal)
        
    'rule' FlatExpressionOperand(-> Sentinal):
        CustomTerms(-> Term)
        PushOperatorExpressionOperand(Term -> Sentinal)

----------

'nonterm' TermExpression(-> EXPRESSION)

    'rule' TermExpression(-> Constant):
        ConstantTermExpression(-> Constant)

    'rule' TermExpression(-> slot(Position, Name)):
        QualifiedId(-> Name) @(-> Position)
        
    'rule' TermExpression(-> result(Position)):
        "the" @(-> Position) "result"

    --'rule' TermExpression(-> as(Position, Value, Type)):
    --    TermExpression(-> Value) "as" @(-> Position) Type(-> Type)

    'rule' TermExpression(-> call(Position, Handler, Arguments)):
        QualifiedId(-> Handler) @(-> Position) "(" OptionalExpressionList(-> Arguments) ")"

    'rule' TermExpression(-> list(Position, List)):
        "[" @(-> Position) OptionalExpressionList(-> List) "]"

    'rule' TermExpression(-> array(Position, Pairs)):
        "{" @(-> Position) OptionalExpressionArray(-> Pairs) "}"

    'rule' TermExpression(-> Expression):
        "(" Expression(-> Expression) ")"

/*'nonterm' ConstantTermExpressionList(-> EXPRESSIONLIST)

    'rule' ConstantTermExpressionList(-> expressionlist(Head, Tail)):
        ConstantTermExpression(-> Head) "," ConstantTermExpressionList(-> Tail)
        
    'rule' ConstantTermExpressionList(-> expressionlist(Tail, nil)):
        ConstantTermExpression(-> Tail)*/

'nonterm' ConstantTermExpression(-> EXPRESSION)

    'rule' ConstantTermExpression(-> undefined(Position)):
        "nothing" @(-> Position)

    'rule' ConstantTermExpression(-> true(Position)):
        "true" @(-> Position)

    'rule' ConstantTermExpression(-> false(Position)):
        "false" @(-> Position)

    'rule' ConstantTermExpression(-> unsignedinteger(Position, Value)):
        INTEGER_LITERAL(-> Value) @(-> Position)

    'rule' ConstantTermExpression(-> real(Position, Value)):
        DOUBLE_LITERAL(-> Value) @(-> Position)

    'rule' ConstantTermExpression(-> string(Position, Value)):
        StringLiteral(-> Value) @(-> Position)
        
/*    'rule' ConstantTermExpression(-> list(Position, Value)):
        "[" @(-> Position) ConstantTermExpressionList(-> Value) "]"
        
    'rule' ConstantTermExpression(-> list(Position, nil)):
        "[" @(-> Position) "]"*/

----------

'nonterm' OptionalExpressionList(-> EXPRESSIONLIST)

    'rule' OptionalExpressionList(-> List):
        ExpressionList(-> List)
    
    'rule' OptionalExpressionList(-> nil)
        -- empty

'nonterm' ExpressionList(-> EXPRESSIONLIST)

    'rule' ExpressionList(-> expressionlist(Head, Tail)):
        Expression(-> Head) "," ExpressionList(-> Tail)
        
    'rule' ExpressionList(-> expressionlist(Expression, nil)):
        Expression(-> Expression)

'nonterm' ExpressionListAsExpression(-> EXPRESSION)

    'rule' ExpressionListAsExpression(-> list(Position, List)):
        ExpressionList(-> List) @(-> Position)

----------

'nonterm' OptionalExpressionArray(-> EXPRESSIONLIST)

    'rule' OptionalExpressionArray(-> Pairs):
        ExpressionArray(-> Pairs)

    'rule' OptionalExpressionArray(-> nil):
        -- empty

'nonterm' ExpressionArray(-> EXPRESSIONLIST)

    'rule' ExpressionArray(-> expressionlist(Head, Tail)):
        ExpressionArrayEntry(-> Head) "," ExpressionArray(-> Tail)

    'rule' ExpressionArray(-> expressionlist(Head, nil)):
        ExpressionArrayEntry(-> Head)

'nonterm' ExpressionArrayEntry(-> EXPRESSION)

    'rule' ExpressionArrayEntry(-> pair(Position, Key, Value)):
        Expression(-> Key) ":" @(-> Position) Expression(-> Value)

--------------------------------------------------------------------------------
-- Syntax Syntax
--------------------------------------------------------------------------------

'nonterm' Syntax(-> SYNTAX)

    'rule' Syntax(-> Syntax):
        AlternateSyntax(-> Syntax)

'nonterm' AlternateSyntax(-> SYNTAX)

    'rule' AlternateSyntax(-> alternate(Position, Left, Right)):
        AlternateSyntax(-> Left) "|" @(-> Position) ConcatenateSyntax(-> Right)

    'rule' AlternateSyntax(-> Syntax)
        ConcatenateSyntax(-> Syntax)
        
'nonterm' ConcatenateSyntax(-> SYNTAX)

    'rule' ConcatenateSyntax(-> concatenate(Position, Left, Right)):
        ConcatenateSyntax(-> Left) @(-> Position) AtomicSyntax(-> Right)

    'rule' ConcatenateSyntax(-> Syntax)
        AtomicSyntax(-> Syntax)
        
'nonterm' AtomicSyntax(-> SYNTAX)

    'rule' AtomicSyntax(-> repeat(Position, Element)):
        "{" @(-> Position) Syntax(-> Element) "}"

    'rule' AtomicSyntax(-> list(Position, Element, Delimiter)):
        "{" @(-> Position) Syntax(-> Element) "," Syntax(-> Delimiter) "}"
        
    'rule' AtomicSyntax(-> optional(Position, Operand)):
        "[" @(-> Position) Syntax(-> Operand) "]"
        
    'rule' AtomicSyntax(-> keyword(Position, Value)):
        StringLiteral(-> Value) @(-> Position)

    'rule' AtomicSyntax(-> unreservedkeyword(Position, Value)):
        StringLiteral(-> Value) @(-> Position) "!"
        
    'rule' AtomicSyntax(-> rule(Position, Name)):
        "<" @(-> Position) Identifier(-> Name) ">"
        
    'rule' AtomicSyntax(-> markedrule(Position, Variable, Name)):
        "<" @(-> Position) Identifier(-> Variable) ":" Identifier(-> Name) ">"
        
    'rule' AtomicSyntax(-> mark(Position, Variable, Value)):
        "<" @(-> Position) Identifier(-> Variable) "=" Constant(-> Value) ">"
        
    'rule' AtomicSyntax(-> Syntax):
        "(" Syntax(-> Syntax) ")"

'nonterm' OptionalConstantList(-> SYNTAXCONSTANTLIST)

    'rule' OptionalConstantList(-> List):
        ConstantList(-> List)
        
    'rule' OptionalConstantList(-> nil):
        -- empty

'nonterm' ConstantList(-> SYNTAXCONSTANTLIST)

    'rule' ConstantList(-> constantlist(Head, Tail)):
        Constant(-> Head) "," ConstantList(-> Tail)

    'rule' ConstantList(-> constantlist(Head, nil)):
        Constant(-> Head)

'nonterm' Constant(-> SYNTAXCONSTANT)

    'rule' Constant(-> undefined(Position)):
        "nothing" @(-> Position)
        
    'rule' Constant(-> true(Position)):
        "true" @(-> Position)
        
    'rule' Constant(-> false(Position)):
        "false" @(-> Position)

    'rule' Constant(-> integer(Position, Value)):
        INTEGER_LITERAL(-> Value) @(-> Position)

    'rule' Constant(-> integer(Position, Value)):
        "-" INTEGER_LITERAL(-> PositiveValue) @(-> Position)
        where(-PositiveValue -> Value)

    'rule' Constant(-> integer(Position, Value)):
        "+" INTEGER_LITERAL(-> Value) @(-> Position)

    'rule' Constant(-> real(Position, Value)):
        DOUBLE_LITERAL(-> Value) @(-> Position)

    'rule' Constant(-> real(Position, PosValue)):
        "-" DOUBLE_LITERAL(-> Value) @(-> Position)
        NegateReal(Value -> PosValue)

    'rule' Constant(-> real(Position, Value)):
        "+" DOUBLE_LITERAL(-> Value) @(-> Position)

    'rule' Constant(-> string(Position, Value)):
        StringLiteral(-> Value) @(-> Position)

    'rule' Constant(-> variable(Position, Value)):
        Identifier(-> Value) @(-> Position)

    'rule' Constant(-> indexedvariable(Position, Value, Index)):
        Identifier(-> Value) @(-> Position) "[" INTEGER_LITERAL(-> Index) "]"
        
    'rule' Constant(-> variable(Position, Value)):
        "output" @(-> Position)
        MakeNameLiteral("output" -> Identifier)
		AssignId(Position, Identifier, nil -> Value)

    'rule' Constant(-> variable(Position, Value)):
        "input" @(-> Position)
        MakeNameLiteral("input" -> Identifier)
        AssignId(Position, Identifier, nil -> Value)

--------------------------------------------------------------------------------
-- Identifier Syntax
--------------------------------------------------------------------------------

'nonterm' Identifier(-> ID)

    'rule' Identifier(-> Id):
        NAME_LITERAL(-> Identifier) @(-> Position)
		AssignId(Position, Identifier, nil -> Id)

    'rule' Identifier(-> Id):
        "iterator" @(-> Position)
        MakeNameLiteral("iterator" -> Identifier)
		AssignId(Position, Identifier, nil -> Id)
        
    'rule' Identifier(-> Id):
        CustomKeywords(-> String) @(-> Position)
        MakeNameLiteral(String -> Identifier)
		AssignId(Position, Identifier, nil -> Id)

'nonterm' StringyIdentifier(-> ID)

    'rule' StringyIdentifier(-> Id):
        StringLiteral(-> String) @(-> Position)
        MakeNameLiteral(String -> Identifier)
		AssignId(Position, Identifier, nil -> Id)

'nonterm' IdentifierList(-> IDLIST)

    'rule' IdentifierList(-> idlist(Head, Tail)):
        QualifiedId(-> Head) "," IdentifierList(-> Tail)
        
    'rule' IdentifierList(-> idlist(Id, nil)):
        QualifiedId(-> Id)

'nonterm' QualifiedId(-> ID)

	'rule' QualifiedId(-> Id):
		NAME_LITERAL(-> Identifier) @(-> Position)
		QualifiedNameToId(Position, Identifier -> Id)
		
'action' QualifiedNameToId(POS, NAME -> ID)

	'rule' QualifiedNameToId(Position, Name -> Id):		
		ContainsNamespaceOperator(Name)
		SplitNamespace(Name -> Namespace, Identifier)
		QualifiedNameToOptionalId(Position, Namespace -> NamespaceId)
		AssignId(Position, Identifier, NamespaceId -> Id)

	'rule' QualifiedNameToId(Position, Name -> Id)
		AssignId(Position, Name, nil -> Id)

'action' QualifiedNameToOptionalId(POS, NAME -> OPTIONALID)

	'rule' QualifiedNameToOptionalId(Position, Name -> id(Id))
		QualifiedNameToId(Position, Name -> Id)

'action' AssignId(POS, NAME, OPTIONALID -> ID)
	
	'rule' AssignId(Position, Identifier, Namespace -> Id)
		Id::ID
        Id'Position <- Position
        Id'Name <- Identifier
        Id'Meaning <- nil
        Id'Namespace <- Namespace
        (|
        	ContainsNamespaceOperator(Identifier)
        	Error_IllegalNamespaceOperator(Position)
		||
        |)
        
'action' GetQualifiedName(ID -> NAME)

	'rule' GetQualifiedName(Id -> Name):
		Id'Namespace -> Namespace
		ResolveIdInNamespace(Namespace, Id -> Name)

'action' ResolveIdInNamespace(OPTIONALID, ID -> NAME)

	'rule' ResolveIdInNamespace(id(NamespaceId), Id -> Name):
		Id'Name -> UnqualifiedName
		GetQualifiedName(NamespaceId -> Namespace)
		ConcatenateNameParts(Namespace, UnqualifiedName -> Name)

	'rule' ResolveIdInNamespace(nil, Id -> Name):
		Id'Name -> Name

'condition' ResolveNamespace(OPTIONALID -> NAME)

	'rule' ResolveNamespace(id(NamespaceId) -> Name):
		GetQualifiedName(NamespaceId -> Name)

--------------------------------------------------------------------------------
-- Separator
--------------------------------------------------------------------------------

'nonterm' OptionalSeparator

    'rule' OptionalSeparator:
        Separator
        
    'rule' OptionalSeparator:
        -- empty
        
'nonterm' Separator

    'rule' Separator:
        SEPARATOR Separator
        
    'rule' Separator:
        SEPARATOR

--------------------------------------------------------------------------------
-- Tokens
--------------------------------------------------------------------------------

'nonterm' StringLiteral(-> STRING)

    'rule' StringLiteral(-> Value):
        STRING_LITERAL(-> EscapedValue) @(-> Position)
        (|
            UnescapeStringLiteral(Position, EscapedValue -> Value)
        ||
            Error_MalformedEscapedString(Position, EscapedValue)
            where(EscapedValue -> Value)
        |)

'nonterm' StringOrNameLiteral(-> STRING)

    'rule' StringOrNameLiteral(-> String):
        StringLiteral(-> String)
        
    'rule' StringOrNameLiteral(-> String):
        NAME_LITERAL(-> Name)
        GetStringOfNameLiteral(Name -> String)

'token' NAME_LITERAL (-> NAME)
'token' INTEGER_LITERAL (-> INT)
'token' DOUBLE_LITERAL (-> DOUBLE)
'token' STRING_LITERAL (-> STRING)

'token' SEPARATOR

'token' END_OF_UNIT
'token' NEXT_UNIT

'action' DefineCustomInvokeList(INT, INVOKELIST)
'action' LookupCustomInvokeList(INT -> INVOKELIST)

'action' CustomInvokeLists(INT -> INVOKELIST)
    'rule' CustomInvokeLists(Index -> List):
        LookupCustomInvokeList(Index -> List)

'action' MakeCustomInvokeMethodArgs1(MODE, INT -> INVOKESIGNATURE)
    'rule' MakeCustomInvokeMethodArgs1(Mode, Index -> invokesignature(Mode, Index, nil)):
    
'action' MakeCustomInvokeMethodArgs2(MODE, INT, MODE, INT -> INVOKESIGNATURE)
    'rule' MakeCustomInvokeMethodArgs2(Mode1, Index1, Mode2, Index2 -> invokesignature(Mode1, Index1, invokesignature(Mode2, Index2, nil))):

'action' MakeCustomInvokeMethodArgs3(MODE, INT, MODE, INT, MODE, INT, -> INVOKESIGNATURE)
    'rule' MakeCustomInvokeMethodArgs3(Mode1, Index1, Mode2, Index2, Mode3, Index3 -> invokesignature(Mode1, Index1, invokesignature(Mode2, Index2, invokesignature(Mode3, Index3, nil)))):

'action' MakeCustomInvokeMethodList(STRING, INVOKEMETHODTYPE, INVOKESIGNATURE, INVOKEMETHODLIST -> INVOKEMETHODLIST)
    'rule' MakeCustomInvokeMethodList(Name, Type, Signature, Previous -> methodlist(Name, Type, Signature, Previous))

'action' MakeCustomInvokeList(STRING, STRING, INVOKEMETHODLIST, INVOKELIST -> INVOKELIST)
    'rule' MakeCustomInvokeList(Name, ModuleName, Methods, Previous -> List)
        Info::INVOKEINFO
        Info'Index <- -1
        Info'ModuleIndex <- -1
        Info'Name <- Name
        Info'ModuleName <- ModuleName
        Info'Methods <- Methods
        where(invokelist(Info, Previous) -> List)

--*--*--*--*--*--*--*--
'nonterm' CustomRule0(-> STATEMENT)
  'rule' CustomRule0(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, nil))))):
    "broken" @(-> Position) "test" Expression(-> Mark0) "when" Expression(-> Mark1) "because" Expression(-> Mark2)
    CustomInvokeLists(0 -> Invoke)
'nonterm' CustomRule1(-> STATEMENT)
  'rule' CustomRule1(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "broken" @(-> Position) "test" Expression(-> Mark0) "because" Expression(-> Mark1)
    CustomInvokeLists(1 -> Invoke)
'nonterm' CustomRule2(-> STATEMENT)
  'rule' CustomRule2(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "broken" @(-> Position) "test" Expression(-> Mark0) "when" Expression(-> Mark1)
    CustomInvokeLists(2 -> Invoke)
'nonterm' CustomRule3(-> STATEMENT)
  'rule' CustomRule3(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "broken" @(-> Position) "test" Expression(-> Mark0)
    CustomInvokeLists(3 -> Invoke)
'nonterm' CustomRule4(-> STATEMENT)
  'rule' CustomRule4(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "skip" @(-> Position) "test" Expression(-> Mark0) "because" Expression(-> Mark1)
    CustomInvokeLists(4 -> Invoke)
'nonterm' CustomRule5(-> STATEMENT)
  'rule' CustomRule5(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "skip" @(-> Position) "test" "because" Expression(-> Mark0)
    CustomInvokeLists(5 -> Invoke)
'nonterm' CustomRule6(-> STATEMENT)
  'rule' CustomRule6(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "skip" @(-> Position) "test" Expression(-> Mark0)
    CustomInvokeLists(6 -> Invoke)
'nonterm' CustomRule7(-> STATEMENT)
  'rule' CustomRule7(-> invoke(Position, Invoke, nil)):
    "skip" @(-> Position) "test"
    CustomInvokeLists(7 -> Invoke)
'nonterm' CustomRule8(-> STATEMENT)
  'rule' CustomRule8(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "test" @(-> Position) Expression(-> Mark0) "when" Expression(-> Mark1)
    CustomInvokeLists(8 -> Invoke)
'nonterm' CustomRule9(-> STATEMENT)
  'rule' CustomRule9(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "test" @(-> Position) Expression(-> Mark0)
    CustomInvokeLists(9 -> Invoke)
'nonterm' CustomRule10(-> STATEMENT)
  'rule' CustomRule10(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "test" @(-> Position) "diagnostic" Expression(-> Mark0)
    CustomInvokeLists(10 -> Invoke)
'nonterm' CustomRule11(-> STATEMENT)
  'rule' CustomRule11(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "plan" @(-> Position) Expression(-> Mark0) "tests"
    CustomInvokeLists(11 -> Invoke)
'nonterm' CustomRule12(-> STATEMENT)
  'rule' CustomRule12(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "combine" @(-> Position) Expression(-> Mark0) "with" Expression(-> Mark1)
    CustomInvokeLists(12 -> Invoke)
'nonterm' CustomRule13(-> STATEMENT)
  'rule' CustomRule13(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "split" @(-> Position) Expression(-> Mark0) "by" Expression(-> Mark1)
    CustomInvokeLists(13 -> Invoke)
'nonterm' CustomRule14(-> INT)
  'rule' CustomRule14(-> Sentinal):
    "is" @(-> Position) "a" "list"
    PushOperatorExpressionPostfix(Position, 14, 14 -> Sentinal)
'nonterm' CustomRule15(-> INT)
  'rule' CustomRule15(-> Sentinal):
    "is" @(-> Position) "an" "array"
    PushOperatorExpressionPostfix(Position, 14, 15 -> Sentinal)
'nonterm' CustomRule16(-> INT)
  'rule' CustomRule16(-> Sentinal):
    "is" @(-> Position) "a" "data"
    PushOperatorExpressionPostfix(Position, 14, 16 -> Sentinal)
'nonterm' CustomRule17(-> INT)
  'rule' CustomRule17(-> Sentinal):
    "is" @(-> Position) "a" "string"
    PushOperatorExpressionPostfix(Position, 14, 17 -> Sentinal)
'nonterm' CustomRule18(-> INT)
  'rule' CustomRule18(-> Sentinal):
    "is" @(-> Position) "a" "number"
    PushOperatorExpressionPostfix(Position, 14, 18 -> Sentinal)
'nonterm' CustomRule19(-> INT)
  'rule' CustomRule19(-> Sentinal):
    "is" @(-> Position) "a" "boolean"
    PushOperatorExpressionPostfix(Position, 14, 19 -> Sentinal)
'nonterm' CustomRule20(-> INT)
  'rule' CustomRule20(-> Sentinal):
    "is not" @(-> Position) "empty"
    PushOperatorExpressionPostfix(Position, 14, 20 -> Sentinal)
'nonterm' CustomRule21(-> INT)
  'rule' CustomRule21(-> Sentinal):
    "is" @(-> Position) "empty"
    PushOperatorExpressionPostfix(Position, 14, 21 -> Sentinal)
'nonterm' CustomRule22(-> EXPRESSION)
  'rule' CustomRule22(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "system" "error" "message"
    CustomInvokeLists(22 -> Invoke)
'nonterm' CustomRule23(-> EXPRESSION)
  'rule' CustomRule23(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "system" "error" "code"
    CustomInvokeLists(23 -> Invoke)
'nonterm' CustomRule24(-> STATEMENT)
  'rule' CustomRule24(-> invoke(Position, Invoke, nil)):
    "reset" @(-> Position) "system" "error"
    CustomInvokeLists(24 -> Invoke)
'nonterm' CustomRule25(-> EXPRESSION)
  'rule' CustomRule25(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "command" "arguments"
    CustomInvokeLists(25 -> Invoke)
'nonterm' CustomRule26(-> EXPRESSION)
  'rule' CustomRule26(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "command" "name"
    CustomInvokeLists(26 -> Invoke)
'nonterm' CustomRule28(-> EXPRESSION)
  'rule' CustomRule28(-> Mark0):
    "with" @(-> Position) "status" Expression(-> Mark0)
  'rule' CustomRule28(-> Mark0):
    where(EXPRESSION'nil -> Mark0)
'nonterm' CustomRule27(-> STATEMENT)
  'rule' CustomRule27(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "quit" @(-> Position) CustomRule28(-> Mark0)
    CustomInvokeLists(27 -> Invoke)
'nonterm' CustomRule29(-> EXPRESSION)
  'rule' CustomRule29(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "architecture"
    CustomInvokeLists(29 -> Invoke)
'nonterm' CustomRule30(-> EXPRESSION)
  'rule' CustomRule30(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "operating" "system"
    CustomInvokeLists(30 -> Invoke)
'nonterm' CustomRule31(-> EXPRESSION)
  'rule' CustomRule31(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "empty" "string"
    CustomInvokeLists(31 -> Invoke)
'nonterm' CustomRule32(-> INT)
  'rule' CustomRule32(-> Sentinal):
    "the" @(-> Position) "lower" "of"
    PushOperatorExpressionPrefix(Position, 3, 32 -> Sentinal)
'nonterm' CustomRule33(-> INT)
  'rule' CustomRule33(-> Sentinal):
    "the" @(-> Position) "upper" "of"
    PushOperatorExpressionPrefix(Position, 3, 33 -> Sentinal)
'nonterm' CustomRule34(-> INT)
  'rule' CustomRule34(-> Sentinal):
    "&&" @(-> Position)
    PushOperatorExpressionLeftBinary(Position, 8, 34 -> Sentinal)
'nonterm' CustomRule35(-> STATEMENT)
  'rule' CustomRule35(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, nil))))):
    "replace" @(-> Position) Expression(-> Mark0) "with" Expression(-> Mark1) "in" Expression(-> Mark2)
    CustomInvokeLists(35 -> Invoke)
'nonterm' CustomRule36(-> STATEMENT)
  'rule' CustomRule36(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "write" @(-> Position) Expression(-> Mark0) "to" Expression(-> Mark1)
    CustomInvokeLists(36 -> Invoke)
'nonterm' CustomRule37(-> EXPRESSION)
  'rule' CustomRule37(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "error" "stream"
    CustomInvokeLists(37 -> Invoke)
'nonterm' CustomRule38(-> EXPRESSION)
  'rule' CustomRule38(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "output" "stream"
    CustomInvokeLists(38 -> Invoke)
'nonterm' CustomRule39(-> STATEMENT)
  'rule' CustomRule39(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "sort" @(-> Position) Expression(-> Mark0) "using" "handler" Expression(-> Mark1)
    CustomInvokeLists(39 -> Invoke)
'nonterm' CustomRule40(-> STATEMENT)
  'rule' CustomRule40(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "sort" @(-> Position) Expression(-> Mark0) "in" "descending" "chronological" "order"
    CustomInvokeLists(40 -> Invoke)
'nonterm' CustomRule41(-> STATEMENT)
  'rule' CustomRule41(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "sort" @(-> Position) Expression(-> Mark0) "in" "ascending" "chronological" "order"
    CustomInvokeLists(41 -> Invoke)
'nonterm' CustomRule42(-> STATEMENT)
  'rule' CustomRule42(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "sort" @(-> Position) Expression(-> Mark0) "in" "descending" "numeric" "order"
    CustomInvokeLists(42 -> Invoke)
'nonterm' CustomRule43(-> STATEMENT)
  'rule' CustomRule43(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "sort" @(-> Position) Expression(-> Mark0) "in" "ascending" "numeric" "order"
    CustomInvokeLists(43 -> Invoke)
'nonterm' CustomRule44(-> STATEMENT)
  'rule' CustomRule44(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "sort" @(-> Position) Expression(-> Mark0) "in" "descending" "byte" "order"
    CustomInvokeLists(44 -> Invoke)
'nonterm' CustomRule45(-> STATEMENT)
  'rule' CustomRule45(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "sort" @(-> Position) Expression(-> Mark0) "in" "ascending" "byte" "order"
    CustomInvokeLists(45 -> Invoke)
'nonterm' CustomRule46(-> STATEMENT)
  'rule' CustomRule46(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "sort" @(-> Position) Expression(-> Mark0) "in" "descending" "text" "order"
    CustomInvokeLists(46 -> Invoke)
'nonterm' CustomRule47(-> STATEMENT)
  'rule' CustomRule47(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "sort" @(-> Position) Expression(-> Mark0) "in" "ascending" "text" "order"
    CustomInvokeLists(47 -> Invoke)
'nonterm' CustomRule48(-> STATEMENT)
  'rule' CustomRule48(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "sort" @(-> Position) Expression(-> Mark0) "in" "descending" "order"
    CustomInvokeLists(48 -> Invoke)
'nonterm' CustomRule50(-> )
  'rule' CustomRule50(-> ):
    "in" @(-> Position) "ascending" "order"
  'rule' CustomRule50(-> ):
'nonterm' CustomRule49(-> STATEMENT)
  'rule' CustomRule49(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "sort" @(-> Position) Expression(-> Mark0) CustomRule50(-> )
    CustomInvokeLists(49 -> Invoke)
'nonterm' CustomRule51(-> INT)
  'rule' CustomRule51(-> Sentinal):
    "the" @(-> Position) "ceiling" "of"
    PushOperatorExpressionPrefix(Position, 3, 51 -> Sentinal)
'nonterm' CustomRule52(-> INT)
  'rule' CustomRule52(-> Sentinal):
    "the" @(-> Position) "floor" "of"
    PushOperatorExpressionPrefix(Position, 3, 52 -> Sentinal)
'nonterm' CustomRule53(-> INT)
  'rule' CustomRule53(-> Sentinal):
    "the" @(-> Position) "rounded" "of"
    PushOperatorExpressionPrefix(Position, 3, 53 -> Sentinal)
'nonterm' CustomRule54(-> STATEMENT)
  'rule' CustomRule54(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "round" @(-> Position) Expression(-> Mark0)
    CustomInvokeLists(54 -> Invoke)
'nonterm' CustomRule55(-> EXPRESSION)
  'rule' CustomRule55(-> invoke(Position, Invoke, nil)):
    "pi" @(-> Position)
    CustomInvokeLists(55 -> Invoke)
'nonterm' CustomRule56(-> INT)
  'rule' CustomRule56(-> Sentinal):
    "converted" @(-> Position) "from" "base" Expression(-> Mark1) "to" "base"
    PushOperatorExpressionLeftBinary(Position, 4, 56 -> Sentinal)
    PushOperatorExpressionArgument(Mark1 -> _)
'nonterm' CustomRule57(-> INT)
  'rule' CustomRule57(-> Sentinal):
    "converted" @(-> Position) "to" "base"
    PushOperatorExpressionLeftBinary(Position, 4, 57 -> Sentinal)
'nonterm' CustomRule58(-> INT)
  'rule' CustomRule58(-> Sentinal):
    "converted" @(-> Position) "from" "base"
    PushOperatorExpressionLeftBinary(Position, 4, 58 -> Sentinal)
'nonterm' CustomRule59(-> INT)
  'rule' CustomRule59(-> Sentinal):
    "the" @(-> Position) "square" "root" "of"
    PushOperatorExpressionPrefix(Position, 3, 59 -> Sentinal)
'nonterm' CustomRule60(-> INT)
  'rule' CustomRule60(-> Sentinal):
    "the" @(-> Position) "maximum" "value" "of"
    PushOperatorExpressionPrefix(Position, 3, 60 -> Sentinal)
'nonterm' CustomRule61(-> INT)
  'rule' CustomRule61(-> Sentinal):
    "the" @(-> Position) "minimum" "value" "of"
    PushOperatorExpressionPrefix(Position, 3, 61 -> Sentinal)
'nonterm' CustomRule62(-> INT)
  'rule' CustomRule62(-> Sentinal):
    "the" @(-> Position) "maximum" "of" Expression(-> Mark0) "and"
    PushOperatorExpressionPrefix(Position, 3, 62 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule63(-> INT)
  'rule' CustomRule63(-> Sentinal):
    "the" @(-> Position) "minimum" "of" Expression(-> Mark0) "and"
    PushOperatorExpressionPrefix(Position, 3, 63 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule64(-> EXPRESSION)
  'rule' CustomRule64(-> invoke(Position, Invoke, nil)):
    "any" @(-> Position) "number"
    CustomInvokeLists(64 -> Invoke)
'nonterm' CustomRule65(-> INT)
  'rule' CustomRule65(-> Sentinal):
    "the" @(-> Position) "abs" "of"
    PushOperatorExpressionPrefix(Position, 3, 65 -> Sentinal)
'nonterm' CustomRule66(-> INT)
  'rule' CustomRule66(-> Sentinal):
    "the" @(-> Position) "trunc" "of"
    PushOperatorExpressionPrefix(Position, 3, 66 -> Sentinal)
'nonterm' CustomRule67(-> INT)
  'rule' CustomRule67(-> Sentinal):
    "the" @(-> Position) "exponential" "of"
    PushOperatorExpressionPrefix(Position, 3, 67 -> Sentinal)
'nonterm' CustomRule68(-> INT)
  'rule' CustomRule68(-> Sentinal):
    "the" @(-> Position) "natural" "log" "of"
    PushOperatorExpressionPrefix(Position, 3, 68 -> Sentinal)
'nonterm' CustomRule69(-> INT)
  'rule' CustomRule69(-> Sentinal):
    "the" @(-> Position) "log" "of"
    PushOperatorExpressionPrefix(Position, 3, 69 -> Sentinal)
'nonterm' CustomRule70(-> INT)
  'rule' CustomRule70(-> Sentinal):
    "the" @(-> Position) "binary" "arctangent" "of" Expression(-> Mark0) "and"
    PushOperatorExpressionPrefix(Position, 3, 70 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule71(-> INT)
  'rule' CustomRule71(-> Sentinal):
    "the" @(-> Position) "arctangent" "of"
    PushOperatorExpressionPrefix(Position, 3, 71 -> Sentinal)
'nonterm' CustomRule72(-> INT)
  'rule' CustomRule72(-> Sentinal):
    "the" @(-> Position) "arccosine" "of"
    PushOperatorExpressionPrefix(Position, 3, 72 -> Sentinal)
'nonterm' CustomRule73(-> INT)
  'rule' CustomRule73(-> Sentinal):
    "the" @(-> Position) "arcsine" "of"
    PushOperatorExpressionPrefix(Position, 3, 73 -> Sentinal)
'nonterm' CustomRule74(-> INT)
  'rule' CustomRule74(-> Sentinal):
    "the" @(-> Position) "tangent" "of"
    PushOperatorExpressionPrefix(Position, 3, 74 -> Sentinal)
'nonterm' CustomRule75(-> INT)
  'rule' CustomRule75(-> Sentinal):
    "the" @(-> Position) "cosine" "of"
    PushOperatorExpressionPrefix(Position, 3, 75 -> Sentinal)
'nonterm' CustomRule76(-> INT)
  'rule' CustomRule76(-> Sentinal):
    "the" @(-> Position) "sine" "of"
    PushOperatorExpressionPrefix(Position, 3, 76 -> Sentinal)
'nonterm' CustomRule77(-> INT)
  'rule' CustomRule77(-> Sentinal):
    "^" @(-> Position)
    PushOperatorExpressionLeftBinary(Position, 5, 77 -> Sentinal)
'nonterm' CustomRule78(-> STATEMENT)
  'rule' CustomRule78(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "parse" @(-> Position) Expression(-> Mark0) "as" "boolean"
    CustomInvokeLists(78 -> Invoke)
'nonterm' CustomRule79(-> INT)
  'rule' CustomRule79(-> Sentinal):
    "parsed" @(-> Position) "as" "boolean"
    PushOperatorExpressionPostfix(Position, 4, 79 -> Sentinal)
'nonterm' CustomRule80(-> INT)
  'rule' CustomRule80(-> Sentinal):
    "not" @(-> Position)
    PushOperatorExpressionPrefix(Position, 15, 80 -> Sentinal)
'nonterm' CustomRule81(-> EXPRESSION)
  'rule' CustomRule81(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "empty" "list"
    CustomInvokeLists(81 -> Invoke)
'nonterm' CustomRule82(-> STATEMENT)
  'rule' CustomRule82(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, nil))))):
    "splice" @(-> Position) Expression(-> Mark0) "after" "element" Expression(-> Mark1) "of" Expression(-> Mark2)
    CustomInvokeLists(82 -> Invoke)
'nonterm' CustomRule83(-> STATEMENT)
  'rule' CustomRule83(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, nil))))):
    "splice" @(-> Position) Expression(-> Mark0) "before" "element" Expression(-> Mark1) "of" Expression(-> Mark2)
    CustomInvokeLists(83 -> Invoke)
'nonterm' CustomRule84(-> STATEMENT)
  'rule' CustomRule84(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, nil))))):
    "splice" @(-> Position) Expression(-> Mark0) "into" "element" Expression(-> Mark1) "of" Expression(-> Mark2)
    CustomInvokeLists(84 -> Invoke)
'nonterm' CustomRule85(-> STATEMENT)
  'rule' CustomRule85(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, expressionlist(Mark3, nil)))))):
    "splice" @(-> Position) Expression(-> Mark0) "into" "element" Expression(-> Mark1) "to" Expression(-> Mark2) "of" Expression(-> Mark3)
    CustomInvokeLists(85 -> Invoke)
'nonterm' CustomRule86(-> STATEMENT)
  'rule' CustomRule86(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "delete" @(-> Position) "the" "last" "element" "of" Expression(-> Mark0)
    CustomInvokeLists(86 -> Invoke)
'nonterm' CustomRule87(-> STATEMENT)
  'rule' CustomRule87(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "delete" @(-> Position) "the" "first" "element" "of" Expression(-> Mark0)
    CustomInvokeLists(87 -> Invoke)
'nonterm' CustomRule88(-> STATEMENT)
  'rule' CustomRule88(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, nil))))):
    "delete" @(-> Position) "element" Expression(-> Mark0) "to" Expression(-> Mark1) "of" Expression(-> Mark2)
    CustomInvokeLists(88 -> Invoke)
'nonterm' CustomRule89(-> STATEMENT)
  'rule' CustomRule89(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "delete" @(-> Position) "element" Expression(-> Mark0) "of" Expression(-> Mark1)
    CustomInvokeLists(89 -> Invoke)
'nonterm' CustomRule90(-> INT)
  'rule' CustomRule90(-> Sentinal):
    "the" @(-> Position) "last" "element" "of"
    PushOperatorExpressionPrefix(Position, 3, 90 -> Sentinal)
'nonterm' CustomRule91(-> INT)
  'rule' CustomRule91(-> Sentinal):
    "the" @(-> Position) "first" "element" "of"
    PushOperatorExpressionPrefix(Position, 3, 91 -> Sentinal)
'nonterm' CustomRule92(-> INT)
  'rule' CustomRule92(-> Sentinal):
    "element" @(-> Position) Expression(-> Mark0) "to" Expression(-> Mark1) "of"
    PushOperatorExpressionPrefix(Position, 3, 92 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
'nonterm' CustomRule93(-> INT)
  'rule' CustomRule93(-> Sentinal):
    "element" @(-> Position) Expression(-> Mark0) "of"
    PushOperatorExpressionPrefix(Position, 3, 93 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule95(-> EXPRESSION)
  'rule' CustomRule95(-> Mark0):
    "front" @(-> Position) "of" 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark0)
  'rule' CustomRule95(-> Mark0):
    "back" @(-> Position) "of" 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
  'rule' CustomRule95(-> Mark0):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
'nonterm' CustomRule94(-> STATEMENT)
  'rule' CustomRule94(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "pop" @(-> Position) CustomRule95(-> Mark0) Expression(-> Mark1)
    CustomInvokeLists(94 -> Invoke)
'nonterm' CustomRule97(-> EXPRESSION)
  'rule' CustomRule97(-> Mark1):
    "front" @(-> Position) "of" 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark1)
  'rule' CustomRule97(-> Mark1):
    "back" @(-> Position) "of" 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark1)
  'rule' CustomRule97(-> Mark1):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark1)
'nonterm' CustomRule96(-> STATEMENT)
  'rule' CustomRule96(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, nil))))):
    "push" @(-> Position) Expression(-> Mark0) "onto" CustomRule97(-> Mark1) Expression(-> Mark2)
    CustomInvokeLists(96 -> Invoke)
'nonterm' CustomRule98(-> INT)
  'rule' CustomRule98(-> Sentinal):
    "the" @(-> Position) "tail" "of"
    PushOperatorExpressionPrefix(Position, 3, 98 -> Sentinal)
'nonterm' CustomRule99(-> INT)
  'rule' CustomRule99(-> Sentinal):
    "the" @(-> Position) "head" "of"
    PushOperatorExpressionPrefix(Position, 3, 99 -> Sentinal)
'nonterm' CustomRule100(-> INT)
  'rule' CustomRule100(-> Sentinal):
    "the" @(-> Position) "entries" "of" "directory"
    PushOperatorExpressionPrefix(Position, 3, 100 -> Sentinal)
'nonterm' CustomRule101(-> STATEMENT)
  'rule' CustomRule101(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "delete" @(-> Position) "directory" Expression(-> Mark0)
    CustomInvokeLists(101 -> Invoke)
'nonterm' CustomRule102(-> STATEMENT)
  'rule' CustomRule102(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "create" @(-> Position) "directory" Expression(-> Mark0)
    CustomInvokeLists(102 -> Invoke)
'nonterm' CustomRule103(-> STATEMENT)
  'rule' CustomRule103(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "delete" @(-> Position) "file" Expression(-> Mark0)
    CustomInvokeLists(103 -> Invoke)
'nonterm' CustomRule104(-> INT)
  'rule' CustomRule104(-> Sentinal):
    "the" @(-> Position) "contents" "of" "file"
    PushOperatorExpressionPrefix(Position, 3, 104 -> Sentinal)
'nonterm' CustomRule105(-> EXPRESSION)
  'rule' CustomRule105(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "universal" "time"
    CustomInvokeLists(105 -> Invoke)
'nonterm' CustomRule106(-> EXPRESSION)
  'rule' CustomRule106(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "universal" "date"
    CustomInvokeLists(106 -> Invoke)
'nonterm' CustomRule107(-> EXPRESSION)
  'rule' CustomRule107(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "local" "date"
    CustomInvokeLists(107 -> Invoke)
'nonterm' CustomRule108(-> EXPRESSION)
  'rule' CustomRule108(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "codeunit" @(-> Position) Expression(-> Mark0)
    CustomInvokeLists(108 -> Invoke)
'nonterm' CustomRule110(-> EXPRESSION)
  'rule' CustomRule110(-> Mark0):
    "first" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark0)
  'rule' CustomRule110(-> Mark0):
    "last" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
  'rule' CustomRule110(-> Mark0):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
'nonterm' CustomRule109(-> INT)
  'rule' CustomRule109(-> Sentinal):
    "the" @(-> Position) CustomRule110(-> Mark0) "offset" "of" "codeunits" Expression(-> Mark1) "before" Expression(-> Mark2) "in"
    PushOperatorExpressionPrefix(Position, 3, 109 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
    PushOperatorExpressionArgument(Mark2 -> _)
'nonterm' CustomRule112(-> EXPRESSION)
  'rule' CustomRule112(-> Mark0):
    "first" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
  'rule' CustomRule112(-> Mark0):
    "last" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark0)
  'rule' CustomRule112(-> Mark0):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
'nonterm' CustomRule111(-> INT)
  'rule' CustomRule111(-> Sentinal):
    "the" @(-> Position) CustomRule112(-> Mark0) "offset" "of" "codeunits" Expression(-> Mark1) "after" Expression(-> Mark2) "in"
    PushOperatorExpressionPrefix(Position, 3, 111 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
    PushOperatorExpressionArgument(Mark2 -> _)
'nonterm' CustomRule114(-> EXPRESSION)
  'rule' CustomRule114(-> Mark0):
    "first" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
  'rule' CustomRule114(-> Mark0):
    "last" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark0)
  'rule' CustomRule114(-> Mark0):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
'nonterm' CustomRule113(-> INT)
  'rule' CustomRule113(-> Sentinal):
    "the" @(-> Position) CustomRule114(-> Mark0) "offset" "of" "codeunits" Expression(-> Mark1) "in"
    PushOperatorExpressionPrefix(Position, 3, 113 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
'nonterm' CustomRule115(-> STATEMENT)
  'rule' CustomRule115(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "delete" @(-> Position) "the" "last" "codeunit" "of" Expression(-> Mark0)
    CustomInvokeLists(115 -> Invoke)
'nonterm' CustomRule116(-> STATEMENT)
  'rule' CustomRule116(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "delete" @(-> Position) "the" "first" "codeunit" "of" Expression(-> Mark0)
    CustomInvokeLists(116 -> Invoke)
'nonterm' CustomRule117(-> STATEMENT)
  'rule' CustomRule117(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, nil))))):
    "delete" @(-> Position) "codeunit" Expression(-> Mark0) "to" Expression(-> Mark1) "of" Expression(-> Mark2)
    CustomInvokeLists(117 -> Invoke)
'nonterm' CustomRule118(-> STATEMENT)
  'rule' CustomRule118(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "delete" @(-> Position) "codeunit" Expression(-> Mark0) "of" Expression(-> Mark1)
    CustomInvokeLists(118 -> Invoke)
'nonterm' CustomRule119(-> INT)
  'rule' CustomRule119(-> Sentinal):
    "the" @(-> Position) "last" "codeunit" "of"
    PushOperatorExpressionPrefix(Position, 3, 119 -> Sentinal)
'nonterm' CustomRule120(-> INT)
  'rule' CustomRule120(-> Sentinal):
    "the" @(-> Position) "first" "codeunit" "of"
    PushOperatorExpressionPrefix(Position, 3, 120 -> Sentinal)
'nonterm' CustomRule121(-> INT)
  'rule' CustomRule121(-> Sentinal):
    "codeunit" @(-> Position) Expression(-> Mark0) "to" Expression(-> Mark1) "of"
    PushOperatorExpressionPrefix(Position, 3, 121 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
'nonterm' CustomRule122(-> INT)
  'rule' CustomRule122(-> Sentinal):
    "codeunit" @(-> Position) Expression(-> Mark0) "of"
    PushOperatorExpressionPrefix(Position, 3, 122 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule123(-> INT)
  'rule' CustomRule123(-> Sentinal):
    "the" @(-> Position) "number" "of" "codeunits" "in"
    PushOperatorExpressionPrefix(Position, 3, 123 -> Sentinal)
'nonterm' CustomRule124(-> INT)
  'rule' CustomRule124(-> Sentinal):
    "the" @(-> Position) "char" "with" "code"
    PushOperatorExpressionPrefix(Position, 3, 124 -> Sentinal)
'nonterm' CustomRule125(-> EXPRESSION)
  'rule' CustomRule125(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "char" @(-> Position) Expression(-> Mark0)
    CustomInvokeLists(125 -> Invoke)
'nonterm' CustomRule126(-> EXPRESSION)
  'rule' CustomRule126(-> invoke(Position, Invoke, nil)):
    "newline" @(-> Position)
    CustomInvokeLists(126 -> Invoke)
'nonterm' CustomRule127(-> INT)
  'rule' CustomRule127(-> Sentinal):
    "is" @(-> Position) "in"
    PushOperatorExpressionNeutralBinary(Position, 14, 127 -> Sentinal)
'nonterm' CustomRule128(-> STATEMENT)
  'rule' CustomRule128(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "delete" @(-> Position) "the" "last" "char" "of" Expression(-> Mark0)
    CustomInvokeLists(128 -> Invoke)
'nonterm' CustomRule129(-> STATEMENT)
  'rule' CustomRule129(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "delete" @(-> Position) "the" "first" "char" "of" Expression(-> Mark0)
    CustomInvokeLists(129 -> Invoke)
'nonterm' CustomRule130(-> STATEMENT)
  'rule' CustomRule130(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, nil))))):
    "delete" @(-> Position) "char" Expression(-> Mark0) "to" Expression(-> Mark1) "of" Expression(-> Mark2)
    CustomInvokeLists(130 -> Invoke)
'nonterm' CustomRule131(-> STATEMENT)
  'rule' CustomRule131(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "delete" @(-> Position) "char" Expression(-> Mark0) "of" Expression(-> Mark1)
    CustomInvokeLists(131 -> Invoke)
'nonterm' CustomRule132(-> INT)
  'rule' CustomRule132(-> Sentinal):
    "the" @(-> Position) "last" "char" "of"
    PushOperatorExpressionPrefix(Position, 3, 132 -> Sentinal)
'nonterm' CustomRule133(-> INT)
  'rule' CustomRule133(-> Sentinal):
    "the" @(-> Position) "first" "char" "of"
    PushOperatorExpressionPrefix(Position, 3, 133 -> Sentinal)
'nonterm' CustomRule134(-> INT)
  'rule' CustomRule134(-> Sentinal):
    "char" @(-> Position) Expression(-> Mark0) "to" Expression(-> Mark1) "of"
    PushOperatorExpressionPrefix(Position, 3, 134 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
'nonterm' CustomRule135(-> INT)
  'rule' CustomRule135(-> Sentinal):
    "char" @(-> Position) Expression(-> Mark0) "of"
    PushOperatorExpressionPrefix(Position, 3, 135 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule136(-> INT)
  'rule' CustomRule136(-> Sentinal):
    "the" @(-> Position) "number" "of" "chars" "in"
    PushOperatorExpressionPrefix(Position, 3, 136 -> Sentinal)
'nonterm' CustomRule137(-> INT)
  'rule' CustomRule137(-> Sentinal):
    "the" @(-> Position) "code" "of"
    PushOperatorExpressionPrefix(Position, 3, 137 -> Sentinal)
'nonterm' CustomRule138(-> INT)
  'rule' CustomRule138(-> Sentinal):
    "the" @(-> Position) "byte" "with" "code"
    PushOperatorExpressionPrefix(Position, 3, 138 -> Sentinal)
'nonterm' CustomRule139(-> STATEMENT)
  'rule' CustomRule139(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "reverse" @(-> Position) Expression(-> Mark0)
    CustomInvokeLists(139 -> Invoke)
'nonterm' CustomRule140(-> INT)
  'rule' CustomRule140(-> Sentinal):
    "random" @(-> Position) "bytes"
    PushOperatorExpressionPostfix(Position, 13, 140 -> Sentinal)
'nonterm' CustomRule141(-> EXPRESSION)
  'rule' CustomRule141(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "byte" @(-> Position) Expression(-> Mark0)
    CustomInvokeLists(141 -> Invoke)
'nonterm' CustomRule142(-> STATEMENT)
  'rule' CustomRule142(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "delete" @(-> Position) "the" "last" "byte" "of" Expression(-> Mark0)
    CustomInvokeLists(142 -> Invoke)
'nonterm' CustomRule143(-> STATEMENT)
  'rule' CustomRule143(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "delete" @(-> Position) "the" "first" "byte" "of" Expression(-> Mark0)
    CustomInvokeLists(143 -> Invoke)
'nonterm' CustomRule144(-> STATEMENT)
  'rule' CustomRule144(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, nil))))):
    "delete" @(-> Position) "byte" Expression(-> Mark0) "to" Expression(-> Mark1) "of" Expression(-> Mark2)
    CustomInvokeLists(144 -> Invoke)
'nonterm' CustomRule145(-> STATEMENT)
  'rule' CustomRule145(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "delete" @(-> Position) "byte" Expression(-> Mark0) "of" Expression(-> Mark1)
    CustomInvokeLists(145 -> Invoke)
'nonterm' CustomRule146(-> INT)
  'rule' CustomRule146(-> Sentinal):
    "the" @(-> Position) "last" "byte" "of"
    PushOperatorExpressionPrefix(Position, 3, 146 -> Sentinal)
'nonterm' CustomRule147(-> INT)
  'rule' CustomRule147(-> Sentinal):
    "the" @(-> Position) "first" "byte" "of"
    PushOperatorExpressionPrefix(Position, 3, 147 -> Sentinal)
'nonterm' CustomRule148(-> INT)
  'rule' CustomRule148(-> Sentinal):
    "byte" @(-> Position) Expression(-> Mark0) "to" Expression(-> Mark1) "of"
    PushOperatorExpressionPrefix(Position, 3, 148 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
'nonterm' CustomRule149(-> INT)
  'rule' CustomRule149(-> Sentinal):
    "byte" @(-> Position) Expression(-> Mark0) "of"
    PushOperatorExpressionPrefix(Position, 3, 149 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule150(-> INT)
  'rule' CustomRule150(-> Sentinal):
    "ends" @(-> Position) "with"
    PushOperatorExpressionNeutralBinary(Position, 14, 150 -> Sentinal)
'nonterm' CustomRule151(-> INT)
  'rule' CustomRule151(-> Sentinal):
    "begins" @(-> Position) "with"
    PushOperatorExpressionNeutralBinary(Position, 14, 151 -> Sentinal)
'nonterm' CustomRule152(-> INT)
  'rule' CustomRule152(-> Sentinal):
    "contains" @(-> Position)
    PushOperatorExpressionNeutralBinary(Position, 14, 152 -> Sentinal)
'nonterm' CustomRule154(-> EXPRESSION)
  'rule' CustomRule154(-> Mark0):
    "first" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark0)
  'rule' CustomRule154(-> Mark0):
    "last" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
  'rule' CustomRule154(-> Mark0):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
'nonterm' CustomRule153(-> INT)
  'rule' CustomRule153(-> Sentinal):
    "the" @(-> Position) CustomRule154(-> Mark0) "index" "of" Expression(-> Mark1) "before" Expression(-> Mark2) "in"
    PushOperatorExpressionPrefix(Position, 3, 153 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
    PushOperatorExpressionArgument(Mark2 -> _)
'nonterm' CustomRule156(-> EXPRESSION)
  'rule' CustomRule156(-> Mark0):
    "first" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark0)
  'rule' CustomRule156(-> Mark0):
    "last" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
  'rule' CustomRule156(-> Mark0):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
'nonterm' CustomRule155(-> INT)
  'rule' CustomRule155(-> Sentinal):
    "the" @(-> Position) CustomRule156(-> Mark0) "offset" "of" Expression(-> Mark1) "before" Expression(-> Mark2) "in"
    PushOperatorExpressionPrefix(Position, 3, 155 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
    PushOperatorExpressionArgument(Mark2 -> _)
'nonterm' CustomRule158(-> EXPRESSION)
  'rule' CustomRule158(-> Mark0):
    "first" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
  'rule' CustomRule158(-> Mark0):
    "last" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark0)
  'rule' CustomRule158(-> Mark0):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
'nonterm' CustomRule157(-> INT)
  'rule' CustomRule157(-> Sentinal):
    "the" @(-> Position) CustomRule158(-> Mark0) "index" "of" Expression(-> Mark1) "after" Expression(-> Mark2) "in"
    PushOperatorExpressionPrefix(Position, 3, 157 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
    PushOperatorExpressionArgument(Mark2 -> _)
'nonterm' CustomRule160(-> EXPRESSION)
  'rule' CustomRule160(-> Mark0):
    "first" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
  'rule' CustomRule160(-> Mark0):
    "last" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark0)
  'rule' CustomRule160(-> Mark0):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
'nonterm' CustomRule159(-> INT)
  'rule' CustomRule159(-> Sentinal):
    "the" @(-> Position) CustomRule160(-> Mark0) "offset" "of" Expression(-> Mark1) "after" Expression(-> Mark2) "in"
    PushOperatorExpressionPrefix(Position, 3, 159 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
    PushOperatorExpressionArgument(Mark2 -> _)
'nonterm' CustomRule162(-> EXPRESSION)
  'rule' CustomRule162(-> Mark0):
    "first" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
  'rule' CustomRule162(-> Mark0):
    "last" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark0)
  'rule' CustomRule162(-> Mark0):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
'nonterm' CustomRule161(-> INT)
  'rule' CustomRule161(-> Sentinal):
    "the" @(-> Position) CustomRule162(-> Mark0) "index" "of" Expression(-> Mark1) "in"
    PushOperatorExpressionPrefix(Position, 3, 161 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
'nonterm' CustomRule164(-> EXPRESSION)
  'rule' CustomRule164(-> Mark0):
    "first" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
  'rule' CustomRule164(-> Mark0):
    "last" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark0)
  'rule' CustomRule164(-> Mark0):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
'nonterm' CustomRule163(-> INT)
  'rule' CustomRule163(-> Sentinal):
    "the" @(-> Position) CustomRule164(-> Mark0) "offset" "of" Expression(-> Mark1) "in"
    PushOperatorExpressionPrefix(Position, 3, 163 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
'nonterm' CustomRule165(-> INT)
  'rule' CustomRule165(-> Sentinal):
    "the" @(-> Position) "number" "of" "bytes" "in"
    PushOperatorExpressionPrefix(Position, 3, 165 -> Sentinal)
'nonterm' CustomRule166(-> INT)
  'rule' CustomRule166(-> Sentinal):
    "shifted" @(-> Position) "right" "by" Expression(-> Mark1) "bitwise"
    PushOperatorExpressionPostfix(Position, 9, 166 -> Sentinal)
    PushOperatorExpressionArgument(Mark1 -> _)
'nonterm' CustomRule167(-> INT)
  'rule' CustomRule167(-> Sentinal):
    "shifted" @(-> Position) "left" "by" Expression(-> Mark1) "bitwise"
    PushOperatorExpressionPostfix(Position, 9, 167 -> Sentinal)
    PushOperatorExpressionArgument(Mark1 -> _)
'nonterm' CustomRule168(-> INT)
  'rule' CustomRule168(-> Sentinal):
    "bitwise" @(-> Position) "not"
    PushOperatorExpressionPrefix(Position, 6, 168 -> Sentinal)
'nonterm' CustomRule169(-> INT)
  'rule' CustomRule169(-> Sentinal):
    "bitwise xor" @(-> Position)
    PushOperatorExpressionLeftBinary(Position, 11, 169 -> Sentinal)
'nonterm' CustomRule170(-> INT)
  'rule' CustomRule170(-> Sentinal):
    "bitwise or" @(-> Position)
    PushOperatorExpressionLeftBinary(Position, 12, 170 -> Sentinal)
'nonterm' CustomRule171(-> INT)
  'rule' CustomRule171(-> Sentinal):
    "bitwise and" @(-> Position)
    PushOperatorExpressionLeftBinary(Position, 10, 171 -> Sentinal)
'nonterm' CustomRule172(-> EXPRESSION)
  'rule' CustomRule172(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "empty" "data"
    CustomInvokeLists(172 -> Invoke)
'nonterm' CustomRule173(-> INT)
  'rule' CustomRule173(-> Sentinal):
    "&" @(-> Position)
    PushOperatorExpressionLeftBinary(Position, 8, 173 -> Sentinal)
'nonterm' CustomRule174(-> STATEMENT)
  'rule' CustomRule174(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "put" @(-> Position) Expression(-> Mark0) "after" Expression(-> Mark1)
    CustomInvokeLists(174 -> Invoke)
'nonterm' CustomRule175(-> STATEMENT)
  'rule' CustomRule175(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "put" @(-> Position) Expression(-> Mark0) "before" Expression(-> Mark1)
    CustomInvokeLists(175 -> Invoke)
'nonterm' CustomRule177(-> )
  'rule' CustomRule177(-> ):
    "that"
  'rule' CustomRule177(-> ):
'nonterm' CustomRule176(-> STATEMENT)
  'rule' CustomRule176(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "expect" @(-> Position) CustomRule177(-> ) Expression(-> Mark0) "because" Expression(-> Mark1)
    CustomInvokeLists(176 -> Invoke)
'nonterm' CustomRule179(-> )
  'rule' CustomRule179(-> ):
    "that"
  'rule' CustomRule179(-> ):
'nonterm' CustomRule178(-> STATEMENT)
  'rule' CustomRule178(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "expect" @(-> Position) CustomRule179(-> ) Expression(-> Mark0)
    CustomInvokeLists(178 -> Invoke)
'nonterm' CustomRule180(-> EXPRESSION)
  'rule' CustomRule180(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "key" @(-> Position) Expression(-> Mark0)
    CustomInvokeLists(180 -> Invoke)
'nonterm' CustomRule181(-> EXPRESSION)
  'rule' CustomRule181(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "element" @(-> Position) Expression(-> Mark0)
    CustomInvokeLists(181 -> Invoke)
'nonterm' CustomRule182(-> EXPRESSION)
  'rule' CustomRule182(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "empty" "array"
    CustomInvokeLists(182 -> Invoke)
'nonterm' CustomRule183(-> STATEMENT)
  'rule' CustomRule183(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "delete" @(-> Position) Expression(-> Mark0) "[" Expression(-> Mark1) "]"
    CustomInvokeLists(183 -> Invoke)
'nonterm' CustomRule184(-> INT)
  'rule' CustomRule184(-> Sentinal):
    "[" @(-> Position) Expression(-> Mark1) "]"
    PushOperatorExpressionPostfix(Position, 2, 184 -> Sentinal)
    PushOperatorExpressionArgument(Mark1 -> _)
'nonterm' CustomRule186(-> EXPRESSION)
  'rule' CustomRule186(-> Mark1):
    "is not" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark1)
  'rule' CustomRule186(-> Mark1):
    "is" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark1)
  'rule' CustomRule186(-> Mark1):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark1)
'nonterm' CustomRule185(-> INT)
  'rule' CustomRule185(-> Sentinal):
    CustomRule186(-> Mark1) @(-> Position) "among" "the" "elements" "of"
    PushOperatorExpressionNeutralBinary(Position, 14, 185 -> Sentinal)
    PushOperatorExpressionArgument(Mark1 -> _)
'nonterm' CustomRule188(-> EXPRESSION)
  'rule' CustomRule188(-> Mark1):
    "is not" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark1)
  'rule' CustomRule188(-> Mark1):
    "is" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark1)
  'rule' CustomRule188(-> Mark1):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark1)
'nonterm' CustomRule187(-> INT)
  'rule' CustomRule187(-> Sentinal):
    CustomRule188(-> Mark1) @(-> Position) "among" "the" "keys" "of"
    PushOperatorExpressionNeutralBinary(Position, 14, 187 -> Sentinal)
    PushOperatorExpressionArgument(Mark1 -> _)
'nonterm' CustomRule189(-> INT)
  'rule' CustomRule189(-> Sentinal):
    "the" @(-> Position) "number" "of" "elements" "in"
    PushOperatorExpressionPrefix(Position, 3, 189 -> Sentinal)
'nonterm' CustomRule190(-> INT)
  'rule' CustomRule190(-> Sentinal):
    "the" @(-> Position) "elements" "of"
    PushOperatorExpressionPrefix(Position, 3, 190 -> Sentinal)
'nonterm' CustomRule191(-> INT)
  'rule' CustomRule191(-> Sentinal):
    "the" @(-> Position) "keys" "of"
    PushOperatorExpressionPrefix(Position, 3, 191 -> Sentinal)
'nonterm' CustomRule192(-> STATEMENT)
  'rule' CustomRule192(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "parse" @(-> Position) Expression(-> Mark0) "as" "list" "of" "number"
    CustomInvokeLists(192 -> Invoke)
'nonterm' CustomRule193(-> INT)
  'rule' CustomRule193(-> Sentinal):
    "parsed" @(-> Position) "as" "list" "of" "number"
    PushOperatorExpressionPostfix(Position, 4, 193 -> Sentinal)
'nonterm' CustomRule194(-> STATEMENT)
  'rule' CustomRule194(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "parse" @(-> Position) Expression(-> Mark0) "as" "number"
    CustomInvokeLists(194 -> Invoke)
'nonterm' CustomRule195(-> INT)
  'rule' CustomRule195(-> Sentinal):
    "parsed" @(-> Position) "as" "number"
    PushOperatorExpressionPostfix(Position, 4, 195 -> Sentinal)
'nonterm' CustomRule196(-> STATEMENT)
  'rule' CustomRule196(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "format" @(-> Position) Expression(-> Mark0) "as" "string"
    CustomInvokeLists(196 -> Invoke)
'nonterm' CustomRule197(-> INT)
  'rule' CustomRule197(-> Sentinal):
    "formatted" @(-> Position) "as" "string"
    PushOperatorExpressionPostfix(Position, 4, 197 -> Sentinal)
'nonterm' CustomRule198(-> INT)
  'rule' CustomRule198(-> Sentinal):
    "is not" @(-> Position)
    PushOperatorExpressionNeutralBinary(Position, 14, 198 -> Sentinal)
'nonterm' CustomRule199(-> INT)
  'rule' CustomRule199(-> Sentinal):
    "is" @(-> Position)
    PushOperatorExpressionNeutralBinary(Position, 14, 199 -> Sentinal)
'nonterm' CustomRule200(-> INT)
  'rule' CustomRule200(-> Sentinal):
    "=" @(-> Position)
    PushOperatorExpressionNeutralBinary(Position, 14, 200 -> Sentinal)
'nonterm' CustomRule201(-> INT)
  'rule' CustomRule201(-> Sentinal):
    "<=" @(-> Position)
    PushOperatorExpressionNeutralBinary(Position, 14, 201 -> Sentinal)
'nonterm' CustomRule202(-> INT)
  'rule' CustomRule202(-> Sentinal):
    "<" @(-> Position)
    PushOperatorExpressionNeutralBinary(Position, 14, 202 -> Sentinal)
'nonterm' CustomRule203(-> INT)
  'rule' CustomRule203(-> Sentinal):
    ">=" @(-> Position)
    PushOperatorExpressionNeutralBinary(Position, 14, 203 -> Sentinal)
'nonterm' CustomRule204(-> INT)
  'rule' CustomRule204(-> Sentinal):
    ">" @(-> Position)
    PushOperatorExpressionNeutralBinary(Position, 14, 204 -> Sentinal)
'nonterm' CustomRule205(-> INT)
  'rule' CustomRule205(-> Sentinal):
    "wrap" @(-> Position)
    PushOperatorExpressionNeutralBinary(Position, 7, 205 -> Sentinal)
'nonterm' CustomRule206(-> INT)
  'rule' CustomRule206(-> Sentinal):
    "mod" @(-> Position)
    PushOperatorExpressionNeutralBinary(Position, 7, 206 -> Sentinal)
'nonterm' CustomRule207(-> INT)
  'rule' CustomRule207(-> Sentinal):
    "/" @(-> Position)
    PushOperatorExpressionLeftBinary(Position, 7, 207 -> Sentinal)
'nonterm' CustomRule208(-> INT)
  'rule' CustomRule208(-> Sentinal):
    "-" @(-> Position)
    PushOperatorExpressionLeftBinary(Position, 8, 208 -> Sentinal)
'nonterm' CustomRule209(-> INT)
  'rule' CustomRule209(-> Sentinal):
    "+" @(-> Position)
    PushOperatorExpressionLeftBinary(Position, 8, 209 -> Sentinal)
'nonterm' CustomRule210(-> INT)
  'rule' CustomRule210(-> Sentinal):
    "-" @(-> Position)
    PushOperatorExpressionPrefix(Position, 6, 210 -> Sentinal)
'nonterm' CustomRule211(-> INT)
  'rule' CustomRule211(-> Sentinal):
    "+" @(-> Position)
    PushOperatorExpressionPrefix(Position, 6, 211 -> Sentinal)
'nonterm' CustomRule212(-> STATEMENT)
  'rule' CustomRule212(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "divide" @(-> Position) Expression(-> Mark0) "by" Expression(-> Mark1)
    CustomInvokeLists(212 -> Invoke)
'nonterm' CustomRule213(-> STATEMENT)
  'rule' CustomRule213(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "multiply" @(-> Position) Expression(-> Mark0) "by" Expression(-> Mark1)
    CustomInvokeLists(213 -> Invoke)
'nonterm' CustomRule214(-> STATEMENT)
  'rule' CustomRule214(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "subtract" @(-> Position) Expression(-> Mark0) "from" Expression(-> Mark1)
    CustomInvokeLists(214 -> Invoke)
'nonterm' CustomRule215(-> INT)
  'rule' CustomRule215(-> Sentinal):
    "licensed" @(-> Position) "for" "edition"
    PushOperatorExpressionPrefix(Position, 3, 215 -> Sentinal)
'nonterm' CustomRule217(-> EXPRESSION)
  'rule' CustomRule217(-> Mark0):
    "feature" @(-> Position) Expression(-> Mark0) "of"
  'rule' CustomRule217(-> Mark0):
    where(EXPRESSION'nil -> Mark0)
'nonterm' CustomRule216(-> INT)
  'rule' CustomRule216(-> Sentinal):
    "licensed" @(-> Position) "for" CustomRule217(-> Mark0) "extension"
    PushOperatorExpressionPrefix(Position, 3, 216 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule219(-> EXPRESSION)
  'rule' CustomRule219(-> Mark0):
    "feature" @(-> Position) Expression(-> Mark0) "of"
  'rule' CustomRule219(-> Mark0):
    where(EXPRESSION'nil -> Mark0)
'nonterm' CustomRule220(-> EXPRESSION)
  'rule' CustomRule220(-> Mark2):
    "or" @(-> Position) "edition" Expression(-> Mark2)
  'rule' CustomRule220(-> Mark2):
    where(EXPRESSION'nil -> Mark2)
'nonterm' CustomRule218(-> STATEMENT)
  'rule' CustomRule218(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, nil))))):
    "ensure" @(-> Position) "license" "for" CustomRule219(-> Mark0) "extension" Expression(-> Mark1) CustomRule220(-> Mark2)
    CustomInvokeLists(218 -> Invoke)
'nonterm' CustomRule221(-> EXPRESSION)
  'rule' CustomRule221(-> invoke(Position, Invoke, nil)):
    "my" @(-> Position) "native" "layer"
    CustomInvokeLists(221 -> Invoke)
'nonterm' CustomRule222(-> INT)
  'rule' CustomRule222(-> Sentinal):
    "native" @(-> Position) "layer" "of"
    PushOperatorExpressionPrefix(Position, 3, 222 -> Sentinal)
'nonterm' CustomRule223(-> INT)
  'rule' CustomRule223(-> Sentinal):
    "annotation" @(-> Position) Expression(-> Mark0) "of"
    PushOperatorExpressionPrefix(Position, 3, 223 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule224(-> INT)
  'rule' CustomRule224(-> Sentinal):
    "the" @(-> Position) "disabled" "of"
    PushOperatorExpressionPrefix(Position, 3, 224 -> Sentinal)
'nonterm' CustomRule225(-> INT)
  'rule' CustomRule225(-> Sentinal):
    "the" @(-> Position) "enabled" "of"
    PushOperatorExpressionPrefix(Position, 3, 225 -> Sentinal)
'nonterm' CustomRule226(-> INT)
  'rule' CustomRule226(-> Sentinal):
    "the" @(-> Position) "location" "of"
    PushOperatorExpressionPrefix(Position, 3, 226 -> Sentinal)
'nonterm' CustomRule227(-> INT)
  'rule' CustomRule227(-> Sentinal):
    "the" @(-> Position) "rectangle" "of"
    PushOperatorExpressionPrefix(Position, 3, 227 -> Sentinal)
'nonterm' CustomRule228(-> STATEMENT)
  'rule' CustomRule228(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "unplace" @(-> Position) Expression(-> Mark0)
    CustomInvokeLists(228 -> Invoke)
'nonterm' CustomRule230(-> EXPRESSION, EXPRESSION)
  'rule' CustomRule230(-> Mark1, Mark2):
    "below" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark1)
    where(EXPRESSION'nil -> Mark2)
  'rule' CustomRule230(-> Mark1, Mark2):
    "above" @(-> Position) 
    where(EXPRESSION'nil -> Mark1)
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark2)
'nonterm' CustomRule229(-> STATEMENT)
  'rule' CustomRule229(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, expressionlist(Mark3, nil)))))):
    "place" @(-> Position) Expression(-> Mark0) CustomRule230(-> Mark1, Mark2) Expression(-> Mark3)
    CustomInvokeLists(229 -> Invoke)
'nonterm' CustomRule232(-> EXPRESSION)
  'rule' CustomRule232(-> Mark1):
    "bottom" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark1)
  'rule' CustomRule232(-> Mark1):
    "top" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark1)
'nonterm' CustomRule231(-> STATEMENT)
  'rule' CustomRule231(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "place" @(-> Position) Expression(-> Mark0) "at" CustomRule232(-> Mark1)
    CustomInvokeLists(231 -> Invoke)
'nonterm' CustomRule233(-> STATEMENT)
  'rule' CustomRule233(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "place" @(-> Position) Expression(-> Mark0)
    CustomInvokeLists(233 -> Invoke)
'nonterm' CustomRule234(-> INT)
  'rule' CustomRule234(-> Sentinal):
    "a" @(-> Position) "new" "widget"
    PushOperatorExpressionPrefix(Position, 13, 234 -> Sentinal)
'nonterm' CustomRule235(-> EXPRESSION)
  'rule' CustomRule235(-> invoke(Position, Invoke, nil)):
    "my" @(-> Position) "children"
    CustomInvokeLists(235 -> Invoke)
'nonterm' CustomRule236(-> EXPRESSION)
  'rule' CustomRule236(-> invoke(Position, Invoke, nil)):
    "this" @(-> Position) "widget"
    CustomInvokeLists(236 -> Invoke)
'nonterm' CustomRule237(-> EXPRESSION)
  'rule' CustomRule237(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "target"
    CustomInvokeLists(237 -> Invoke)
'nonterm' CustomRule239(-> EXPRESSION)
  'rule' CustomRule239(-> Mark0):
    "returning" @(-> Position) Expression(-> Mark0)
  'rule' CustomRule239(-> Mark0):
    where(EXPRESSION'nil -> Mark0)
'nonterm' CustomRule238(-> STATEMENT)
  'rule' CustomRule238(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "close" @(-> Position) "popup" CustomRule239(-> Mark0)
    CustomInvokeLists(238 -> Invoke)
'nonterm' CustomRule240(-> EXPRESSION)
  'rule' CustomRule240(-> invoke(Position, Invoke, nil)):
    "currently" @(-> Position) "popped" "up"
    CustomInvokeLists(240 -> Invoke)
'nonterm' CustomRule242(-> EXPRESSION)
  'rule' CustomRule242(-> Mark2):
    "with" @(-> Position) "properties" Expression(-> Mark2)
  'rule' CustomRule242(-> Mark2):
    where(EXPRESSION'nil -> Mark2)
'nonterm' CustomRule241(-> STATEMENT)
  'rule' CustomRule241(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, nil))))):
    "popup" @(-> Position) "widget" Expression(-> Mark0) "at" Expression(-> Mark1) CustomRule242(-> Mark2)
    CustomInvokeLists(241 -> Invoke)
'nonterm' CustomRule243(-> STATEMENT)
  'rule' CustomRule243(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "popup" @(-> Position) "menu" Expression(-> Mark0) "at" Expression(-> Mark1)
    CustomInvokeLists(243 -> Invoke)
'nonterm' CustomRule244(-> INT)
  'rule' CustomRule244(-> Sentinal):
    "is not" @(-> Position) "within"
    PushOperatorExpressionNeutralBinary(Position, 14, 244 -> Sentinal)
'nonterm' CustomRule245(-> INT)
  'rule' CustomRule245(-> Sentinal):
    "is" @(-> Position) "within"
    PushOperatorExpressionNeutralBinary(Position, 14, 245 -> Sentinal)
'nonterm' CustomRule246(-> EXPRESSION)
  'rule' CustomRule246(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "touch" "ids"
    CustomInvokeLists(246 -> Invoke)
'nonterm' CustomRule247(-> INT)
  'rule' CustomRule247(-> Sentinal):
    "the" @(-> Position) "position" "of" "touch"
    PushOperatorExpressionPrefix(Position, 3, 247 -> Sentinal)
'nonterm' CustomRule248(-> EXPRESSION)
  'rule' CustomRule248(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "number" "of" "touches"
    CustomInvokeLists(248 -> Invoke)
'nonterm' CustomRule249(-> EXPRESSION)
  'rule' CustomRule249(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "touch" "position"
    CustomInvokeLists(249 -> Invoke)
'nonterm' CustomRule250(-> EXPRESSION)
  'rule' CustomRule250(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "touch" "id"
    CustomInvokeLists(250 -> Invoke)
'nonterm' CustomRule252(-> EXPRESSION)
  'rule' CustomRule252(-> Mark0):
    "current" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark0)
  'rule' CustomRule252(-> Mark0):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
'nonterm' CustomRule251(-> EXPRESSION)
  'rule' CustomRule251(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "the" @(-> Position) CustomRule252(-> Mark0) "click" "count"
    CustomInvokeLists(251 -> Invoke)
'nonterm' CustomRule254(-> EXPRESSION)
  'rule' CustomRule254(-> Mark0):
    "current" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark0)
  'rule' CustomRule254(-> Mark0):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
'nonterm' CustomRule253(-> EXPRESSION)
  'rule' CustomRule253(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "the" @(-> Position) CustomRule254(-> Mark0) "click" "button"
    CustomInvokeLists(253 -> Invoke)
'nonterm' CustomRule256(-> EXPRESSION)
  'rule' CustomRule256(-> Mark0):
    "current" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark0)
  'rule' CustomRule256(-> Mark0):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
'nonterm' CustomRule255(-> EXPRESSION)
  'rule' CustomRule255(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "the" @(-> Position) CustomRule256(-> Mark0) "click" "position"
    CustomInvokeLists(255 -> Invoke)
'nonterm' CustomRule258(-> EXPRESSION)
  'rule' CustomRule258(-> Mark0):
    "current" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark0)
  'rule' CustomRule258(-> Mark0):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
'nonterm' CustomRule257(-> EXPRESSION)
  'rule' CustomRule257(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "the" @(-> Position) CustomRule258(-> Mark0) "mouse" "position"
    CustomInvokeLists(257 -> Invoke)
'nonterm' CustomRule259(-> EXPRESSION)
  'rule' CustomRule259(-> invoke(Position, Invoke, nil)):
    "my" @(-> Position) "pixel" "scale"
    CustomInvokeLists(259 -> Invoke)
'nonterm' CustomRule261(-> EXPRESSION)
  'rule' CustomRule261(-> Mark0):
    "foreground" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 0) -> Mark0)
  'rule' CustomRule261(-> Mark0):
    "background" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 1) -> Mark0)
  'rule' CustomRule261(-> Mark0):
    "highlight" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 2) -> Mark0)
  'rule' CustomRule261(-> Mark0):
    "border" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 3) -> Mark0)
  'rule' CustomRule261(-> Mark0):
    "top" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 4) -> Mark0)
  'rule' CustomRule261(-> Mark0):
    "bottom" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 5) -> Mark0)
  'rule' CustomRule261(-> Mark0):
    "shadow" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 6) -> Mark0)
  'rule' CustomRule261(-> Mark0):
    "focus" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 7) -> Mark0)
'nonterm' CustomRule260(-> EXPRESSION)
  'rule' CustomRule260(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "my" @(-> Position) CustomRule261(-> Mark0) "paint"
    CustomInvokeLists(260 -> Invoke)
'nonterm' CustomRule262(-> EXPRESSION)
  'rule' CustomRule262(-> invoke(Position, Invoke, nil)):
    "my" @(-> Position) "disabled"
    CustomInvokeLists(262 -> Invoke)
'nonterm' CustomRule263(-> EXPRESSION)
  'rule' CustomRule263(-> invoke(Position, Invoke, nil)):
    "my" @(-> Position) "enabled"
    CustomInvokeLists(263 -> Invoke)
'nonterm' CustomRule264(-> EXPRESSION)
  'rule' CustomRule264(-> invoke(Position, Invoke, nil)):
    "my" @(-> Position) "font"
    CustomInvokeLists(264 -> Invoke)
'nonterm' CustomRule265(-> EXPRESSION)
  'rule' CustomRule265(-> invoke(Position, Invoke, nil)):
    "my" @(-> Position) "height"
    CustomInvokeLists(265 -> Invoke)
'nonterm' CustomRule266(-> EXPRESSION)
  'rule' CustomRule266(-> invoke(Position, Invoke, nil)):
    "my" @(-> Position) "width"
    CustomInvokeLists(266 -> Invoke)
'nonterm' CustomRule267(-> EXPRESSION)
  'rule' CustomRule267(-> invoke(Position, Invoke, nil)):
    "my" @(-> Position) "bounds"
    CustomInvokeLists(267 -> Invoke)
'nonterm' CustomRule268(-> EXPRESSION)
  'rule' CustomRule268(-> invoke(Position, Invoke, nil)):
    "my" @(-> Position) "rectangle"
    CustomInvokeLists(268 -> Invoke)
'nonterm' CustomRule269(-> EXPRESSION)
  'rule' CustomRule269(-> invoke(Position, Invoke, nil)):
    "my" @(-> Position) "name"
    CustomInvokeLists(269 -> Invoke)
'nonterm' CustomRule270(-> EXPRESSION)
  'rule' CustomRule270(-> invoke(Position, Invoke, nil)):
    "my" @(-> Position) "script" "object"
    CustomInvokeLists(270 -> Invoke)
'nonterm' CustomRule272(-> EXPRESSION)
  'rule' CustomRule272(-> Mark0):
    "in" @(-> Position) Expression(-> Mark0)
  'rule' CustomRule272(-> Mark0):
    where(EXPRESSION'nil -> Mark0)
'nonterm' CustomRule271(-> STATEMENT)
  'rule' CustomRule271(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "trigger" @(-> Position) "all" CustomRule272(-> Mark0)
    CustomInvokeLists(271 -> Invoke)
'nonterm' CustomRule273(-> EXPRESSION)
  'rule' CustomRule273(-> invoke(Position, Invoke, nil)):
    "in" @(-> Position) "edit" "mode"
    CustomInvokeLists(273 -> Invoke)
'nonterm' CustomRule274(-> STATEMENT)
  'rule' CustomRule274(-> invoke(Position, Invoke, nil)):
    "cancel" @(-> Position) "timer"
    CustomInvokeLists(274 -> Invoke)
'nonterm' CustomRule275(-> STATEMENT)
  'rule' CustomRule275(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "schedule" @(-> Position) "timer" "in" Expression(-> Mark0) "seconds"
    CustomInvokeLists(275 -> Invoke)
'nonterm' CustomRule276(-> STATEMENT)
  'rule' CustomRule276(-> invoke(Position, Invoke, nil)):
    "redraw" @(-> Position) "all"
    CustomInvokeLists(276 -> Invoke)
'nonterm' CustomRule278(-> EXPRESSION)
  'rule' CustomRule278(-> Mark1):
    "relative" @(-> Position) "to" Expression(-> Mark1)
  'rule' CustomRule278(-> Mark1):
    where(EXPRESSION'nil -> Mark1)
'nonterm' CustomRule277(-> STATEMENT)
  'rule' CustomRule277(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "resolve" @(-> Position) "file" Expression(-> Mark0) CustomRule278(-> Mark1)
    CustomInvokeLists(277 -> Invoke)
'nonterm' CustomRule280(-> EXPRESSION)
  'rule' CustomRule280(-> Mark0):
    "shift" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 0) -> Mark0)
  'rule' CustomRule280(-> Mark0):
    "command" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 1) -> Mark0)
  'rule' CustomRule280(-> Mark0):
    "control" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 2) -> Mark0)
  'rule' CustomRule280(-> Mark0):
    "alt" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 3) -> Mark0)
  'rule' CustomRule280(-> Mark0):
    "option" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 3) -> Mark0)
  'rule' CustomRule280(-> Mark0):
    "caps" @(-> Position) "lock" 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 4) -> Mark0)
'nonterm' CustomRule281(-> EXPRESSION)
  'rule' CustomRule281(-> Mark1):
    "currently" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark1)
  'rule' CustomRule281(-> Mark1):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark1)
'nonterm' CustomRule279(-> EXPRESSION)
  'rule' CustomRule279(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "the" @(-> Position) CustomRule280(-> Mark0) "key" "is" CustomRule281(-> Mark1) "down"
    CustomInvokeLists(279 -> Invoke)
'nonterm' CustomRule282(-> EXPRESSION)
  'rule' CustomRule282(-> invoke(Position, Invoke, nil)):
    "my" @(-> Position) "resources" "folder"
    CustomInvokeLists(282 -> Invoke)
'nonterm' CustomRule283(-> EXPRESSION)
  'rule' CustomRule283(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "item" "delimiter"
    CustomInvokeLists(283 -> Invoke)
'nonterm' CustomRule284(-> EXPRESSION)
  'rule' CustomRule284(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "line" "delimiter"
    CustomInvokeLists(284 -> Invoke)
'nonterm' CustomRule285(-> EXPRESSION)
  'rule' CustomRule285(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "row" "delimiter"
    CustomInvokeLists(285 -> Invoke)
'nonterm' CustomRule286(-> EXPRESSION)
  'rule' CustomRule286(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "column" "delimiter"
    CustomInvokeLists(286 -> Invoke)
'nonterm' CustomRule288(-> EXPRESSION)
  'rule' CustomRule288(-> Mark1):
    "with" @(-> Position) Expression(-> Mark1)
  'rule' CustomRule288(-> Mark1):
    where(EXPRESSION'nil -> Mark1)
'nonterm' CustomRule287(-> STATEMENT)
  'rule' CustomRule287(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "log" @(-> Position) Expression(-> Mark0) CustomRule288(-> Mark1)
    CustomInvokeLists(287 -> Invoke)
'nonterm' CustomRule290(-> EXPRESSION)
  'rule' CustomRule290(-> Mark1):
    "in" @(-> Position) Expression(-> Mark1)
  'rule' CustomRule290(-> Mark1):
    where(EXPRESSION'nil -> Mark1)
'nonterm' CustomRule291(-> EXPRESSION)
  'rule' CustomRule291(-> Mark2):
    "with" @(-> Position) Expression(-> Mark2)
  'rule' CustomRule291(-> Mark2):
    where(EXPRESSION'nil -> Mark2)
'nonterm' CustomRule289(-> STATEMENT)
  'rule' CustomRule289(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, nil))))):
    "execute" @(-> Position) "script" Expression(-> Mark0) CustomRule290(-> Mark1) CustomRule291(-> Mark2)
    CustomInvokeLists(289 -> Invoke)
'nonterm' CustomRule292(-> EXPRESSION)
  'rule' CustomRule292(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "caller"
    CustomInvokeLists(292 -> Invoke)
'nonterm' CustomRule293(-> EXPRESSION)
  'rule' CustomRule293(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "message" "was" "not" "handled"
    CustomInvokeLists(293 -> Invoke)
'nonterm' CustomRule294(-> EXPRESSION)
  'rule' CustomRule294(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "message" "was" "handled"
    CustomInvokeLists(294 -> Invoke)
'nonterm' CustomRule296(-> EXPRESSION)
  'rule' CustomRule296(-> Mark1):
    "to" @(-> Position) Expression(-> Mark1)
  'rule' CustomRule296(-> Mark1):
    where(EXPRESSION'nil -> Mark1)
'nonterm' CustomRule297(-> EXPRESSION)
  'rule' CustomRule297(-> Mark2):
    "with" @(-> Position) Expression(-> Mark2)
  'rule' CustomRule297(-> Mark2):
    where(EXPRESSION'nil -> Mark2)
'nonterm' CustomRule295(-> STATEMENT)
  'rule' CustomRule295(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, nil))))):
    "post" @(-> Position) Expression(-> Mark0) CustomRule296(-> Mark1) CustomRule297(-> Mark2)
    CustomInvokeLists(295 -> Invoke)
'nonterm' CustomRule299(-> EXPRESSION)
  'rule' CustomRule299(-> Mark0):
    "function" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark0)
  'rule' CustomRule299(-> Mark0):
    "command" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
  'rule' CustomRule299(-> Mark0):
    
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
'nonterm' CustomRule300(-> EXPRESSION)
  'rule' CustomRule300(-> Mark2):
    "to" @(-> Position) Expression(-> Mark2)
  'rule' CustomRule300(-> Mark2):
    where(EXPRESSION'nil -> Mark2)
'nonterm' CustomRule301(-> EXPRESSION)
  'rule' CustomRule301(-> Mark3):
    "with" @(-> Position) Expression(-> Mark3)
  'rule' CustomRule301(-> Mark3):
    where(EXPRESSION'nil -> Mark3)
'nonterm' CustomRule298(-> STATEMENT)
  'rule' CustomRule298(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, expressionlist(Mark3, nil)))))):
    "send" @(-> Position) CustomRule299(-> Mark0) Expression(-> Mark1) CustomRule300(-> Mark2) CustomRule301(-> Mark3)
    CustomInvokeLists(298 -> Invoke)
'nonterm' CustomRule302(-> INT)
  'rule' CustomRule302(-> Sentinal):
    "the" @(-> Position) "children" "of"
    PushOperatorExpressionPrefix(Position, 3, 302 -> Sentinal)
'nonterm' CustomRule303(-> INT)
  'rule' CustomRule303(-> Sentinal):
    "the" @(-> Position) "owner" "of"
    PushOperatorExpressionPrefix(Position, 3, 303 -> Sentinal)
'nonterm' CustomRule304(-> INT)
  'rule' CustomRule304(-> Sentinal):
    "property" @(-> Position) Expression(-> Mark0) "of"
    PushOperatorExpressionPrefix(Position, 3, 304 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule305(-> INT)
  'rule' CustomRule305(-> Sentinal):
    "does" @(-> Position) "not" "exist"
    PushOperatorExpressionPostfix(Position, 14, 305 -> Sentinal)
'nonterm' CustomRule306(-> INT)
  'rule' CustomRule306(-> Sentinal):
    "exists" @(-> Position)
    PushOperatorExpressionPostfix(Position, 14, 306 -> Sentinal)
'nonterm' CustomRule307(-> STATEMENT)
  'rule' CustomRule307(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "resolve" @(-> Position) "script" "object" Expression(-> Mark0)
    CustomInvokeLists(307 -> Invoke)
'nonterm' CustomRule308(-> INT)
  'rule' CustomRule308(-> Sentinal):
    "the" @(-> Position) "pixel" "height" "of"
    PushOperatorExpressionPrefix(Position, 3, 308 -> Sentinal)
'nonterm' CustomRule309(-> INT)
  'rule' CustomRule309(-> Sentinal):
    "the" @(-> Position) "pixel" "width" "of"
    PushOperatorExpressionPrefix(Position, 3, 309 -> Sentinal)
'nonterm' CustomRule310(-> INT)
  'rule' CustomRule310(-> Sentinal):
    "the" @(-> Position) "pixel" "data" "of"
    PushOperatorExpressionPrefix(Position, 3, 310 -> Sentinal)
'nonterm' CustomRule311(-> INT)
  'rule' CustomRule311(-> Sentinal):
    "a" @(-> Position) "new" "canvas" "with" "size"
    PushOperatorExpressionPrefix(Position, 13, 311 -> Sentinal)
'nonterm' CustomRule312(-> EXPRESSION)
  'rule' CustomRule312(-> invoke(Position, Invoke, nil)):
    "this" @(-> Position) "canvas"
    CustomInvokeLists(312 -> Invoke)
'nonterm' CustomRule313(-> STATEMENT)
  'rule' CustomRule313(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "measure" @(-> Position) Expression(-> Mark0) "on" Expression(-> Mark1)
    CustomInvokeLists(313 -> Invoke)
'nonterm' CustomRule314(-> STATEMENT)
  'rule' CustomRule314(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, expressionlist(Mark3, nil)))))):
    "fill" @(-> Position) "text" Expression(-> Mark0) "at" Custom_CanvasTextAlignment(-> Mark1) "of" Expression(-> Mark2) "on" Expression(-> Mark3)
    CustomInvokeLists(314 -> Invoke)
'nonterm' CustomRule315(-> STATEMENT)
  'rule' CustomRule315(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, nil))))):
    "fill" @(-> Position) "text" Expression(-> Mark0) "at" Expression(-> Mark1) "on" Expression(-> Mark2)
    CustomInvokeLists(315 -> Invoke)
'nonterm' CustomRule317(-> EXPRESSION)
  'rule' CustomRule317(-> Mark0):
    "from" @(-> Position) Expression(-> Mark0) "of"
  'rule' CustomRule317(-> Mark0):
    where(EXPRESSION'nil -> Mark0)
'nonterm' CustomRule316(-> STATEMENT)
  'rule' CustomRule316(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, expressionlist(Mark3, nil)))))):
    "draw" @(-> Position) CustomRule317(-> Mark0) Expression(-> Mark1) "into" Expression(-> Mark2) "of" Expression(-> Mark3)
    CustomInvokeLists(316 -> Invoke)
'nonterm' CustomRule318(-> STATEMENT)
  'rule' CustomRule318(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "clip" @(-> Position) "to" Expression(-> Mark0) "on" Expression(-> Mark1)
    CustomInvokeLists(318 -> Invoke)
'nonterm' CustomRule320(-> EXPRESSION)
  'rule' CustomRule320(-> Mark0):
    Expression(-> Mark0) @(-> Position) "on"
  'rule' CustomRule320(-> Mark0):
    where(EXPRESSION'nil -> Mark0)
'nonterm' CustomRule319(-> STATEMENT)
  'rule' CustomRule319(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "stroke" @(-> Position) CustomRule320(-> Mark0) Expression(-> Mark1)
    CustomInvokeLists(319 -> Invoke)
'nonterm' CustomRule322(-> EXPRESSION)
  'rule' CustomRule322(-> Mark0):
    Expression(-> Mark0) @(-> Position) "on"
  'rule' CustomRule322(-> Mark0):
    where(EXPRESSION'nil -> Mark0)
'nonterm' CustomRule321(-> STATEMENT)
  'rule' CustomRule321(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "fill" @(-> Position) CustomRule322(-> Mark0) Expression(-> Mark1)
    CustomInvokeLists(321 -> Invoke)
'nonterm' CustomRule323(-> STATEMENT)
  'rule' CustomRule323(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "end" @(-> Position) "layer" "on" Expression(-> Mark0)
    CustomInvokeLists(323 -> Invoke)
'nonterm' CustomRule324(-> STATEMENT)
  'rule' CustomRule324(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "begin" @(-> Position) "effect" "only" "layer" "with" Expression(-> Mark0) "on" Expression(-> Mark1)
    CustomInvokeLists(324 -> Invoke)
'nonterm' CustomRule326(-> EXPRESSION)
  'rule' CustomRule326(-> Mark0):
    "with" @(-> Position) Expression(-> Mark0)
  'rule' CustomRule326(-> Mark0):
    where(EXPRESSION'nil -> Mark0)
'nonterm' CustomRule325(-> STATEMENT)
  'rule' CustomRule325(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "begin" @(-> Position) "layer" CustomRule326(-> Mark0) "on" Expression(-> Mark1)
    CustomInvokeLists(325 -> Invoke)
'nonterm' CustomRule327(-> STATEMENT)
  'rule' CustomRule327(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "restore" @(-> Position) "state" "of" Expression(-> Mark0)
    CustomInvokeLists(327 -> Invoke)
'nonterm' CustomRule328(-> STATEMENT)
  'rule' CustomRule328(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "save" @(-> Position) "state" "of" Expression(-> Mark0)
    CustomInvokeLists(328 -> Invoke)
'nonterm' CustomRule329(-> INT)
  'rule' CustomRule329(-> Sentinal):
    "the" @(-> Position) "clipping" "bounds" "of"
    PushOperatorExpressionPrefix(Position, 3, 329 -> Sentinal)
'nonterm' CustomRule330(-> INT)
  'rule' CustomRule330(-> Sentinal):
    "the" @(-> Position) "dash" "phase" "of"
    PushOperatorExpressionPrefix(Position, 3, 330 -> Sentinal)
'nonterm' CustomRule331(-> INT)
  'rule' CustomRule331(-> Sentinal):
    "the" @(-> Position) "dashes" "of"
    PushOperatorExpressionPrefix(Position, 3, 331 -> Sentinal)
'nonterm' CustomRule332(-> INT)
  'rule' CustomRule332(-> Sentinal):
    "the" @(-> Position) "miter" "limit" "of"
    PushOperatorExpressionPrefix(Position, 3, 332 -> Sentinal)
'nonterm' CustomRule333(-> INT)
  'rule' CustomRule333(-> Sentinal):
    "the" @(-> Position) "cap" "style" "of"
    PushOperatorExpressionPrefix(Position, 3, 333 -> Sentinal)
'nonterm' CustomRule334(-> INT)
  'rule' CustomRule334(-> Sentinal):
    "the" @(-> Position) "join" "style" "of"
    PushOperatorExpressionPrefix(Position, 3, 334 -> Sentinal)
'nonterm' CustomRule335(-> INT)
  'rule' CustomRule335(-> Sentinal):
    "the" @(-> Position) "font" "of"
    PushOperatorExpressionPrefix(Position, 3, 335 -> Sentinal)
'nonterm' CustomRule336(-> INT)
  'rule' CustomRule336(-> Sentinal):
    "the" @(-> Position) "stroke" "width" "of"
    PushOperatorExpressionPrefix(Position, 3, 336 -> Sentinal)
'nonterm' CustomRule337(-> INT)
  'rule' CustomRule337(-> Sentinal):
    "the" @(-> Position) "image" "resize" "quality" "of"
    PushOperatorExpressionPrefix(Position, 3, 337 -> Sentinal)
'nonterm' CustomRule338(-> INT)
  'rule' CustomRule338(-> Sentinal):
    "the" @(-> Position) "stippled" "of"
    PushOperatorExpressionPrefix(Position, 3, 338 -> Sentinal)
'nonterm' CustomRule339(-> INT)
  'rule' CustomRule339(-> Sentinal):
    "the" @(-> Position) "opacity" "of"
    PushOperatorExpressionPrefix(Position, 3, 339 -> Sentinal)
'nonterm' CustomRule340(-> INT)
  'rule' CustomRule340(-> Sentinal):
    "the" @(-> Position) "antialias" "of"
    PushOperatorExpressionPrefix(Position, 3, 340 -> Sentinal)
'nonterm' CustomRule341(-> INT)
  'rule' CustomRule341(-> Sentinal):
    "the" @(-> Position) "fill" "rule" "of"
    PushOperatorExpressionPrefix(Position, 3, 341 -> Sentinal)
'nonterm' CustomRule342(-> INT)
  'rule' CustomRule342(-> Sentinal):
    "the" @(-> Position) "paint" "of"
    PushOperatorExpressionPrefix(Position, 3, 342 -> Sentinal)
'nonterm' CustomRule343(-> EXPRESSION)
  'rule' CustomRule343(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "top left" @(-> Position)  
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'integer(UndefinedPosition, -1) -> Mark0)
    where(EXPRESSION'integer(UndefinedPosition, -1) -> Mark1)
    CustomInvokeLists(343 -> Invoke)
  'rule' CustomRule343(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "top" @(-> Position)  
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 0) -> Mark0)
    where(EXPRESSION'integer(UndefinedPosition, -1) -> Mark1)
    CustomInvokeLists(343 -> Invoke)
  'rule' CustomRule343(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "top right" @(-> Position)  
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 1) -> Mark0)
    where(EXPRESSION'integer(UndefinedPosition, -1) -> Mark1)
    CustomInvokeLists(343 -> Invoke)
  'rule' CustomRule343(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "left" @(-> Position)  
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'integer(UndefinedPosition, -1) -> Mark0)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 0) -> Mark1)
    CustomInvokeLists(343 -> Invoke)
  'rule' CustomRule343(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "center" @(-> Position)  
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 0) -> Mark0)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 0) -> Mark1)
    CustomInvokeLists(343 -> Invoke)
  'rule' CustomRule343(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "right" @(-> Position)  
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 1) -> Mark0)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 0) -> Mark1)
    CustomInvokeLists(343 -> Invoke)
  'rule' CustomRule343(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "bottom left" @(-> Position)  
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'integer(UndefinedPosition, -1) -> Mark0)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 1) -> Mark1)
    CustomInvokeLists(343 -> Invoke)
  'rule' CustomRule343(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "bottom" @(-> Position)  
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 0) -> Mark0)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 1) -> Mark1)
    CustomInvokeLists(343 -> Invoke)
  'rule' CustomRule343(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "bottom right" @(-> Position)  
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 1) -> Mark0)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 1) -> Mark1)
    CustomInvokeLists(343 -> Invoke)
'nonterm' Custom_CanvasTextAlignment(-> EXPRESSION)
  'rule' Custom_CanvasTextAlignment(-> Expr):
    CustomRule343(-> Expr)
'nonterm' CustomRule344(-> INT)
  'rule' CustomRule344(-> Sentinal):
    "the" @(-> Position) "image" "bounds" "of" "text" Expression(-> Mark0) "on"
    PushOperatorExpressionPrefix(Position, 3, 344 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule345(-> INT)
  'rule' CustomRule345(-> Sentinal):
    "the" @(-> Position) "image" "bounds" "of" "text" Expression(-> Mark0) "with"
    PushOperatorExpressionPrefix(Position, 3, 345 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule347(-> )
  'rule' CustomRule347(-> ):
    "layout"
  'rule' CustomRule347(-> ):
'nonterm' CustomRule346(-> INT)
  'rule' CustomRule346(-> Sentinal):
    "the" @(-> Position) CustomRule347(-> ) "bounds" "of" "text" Expression(-> Mark0) "on"
    PushOperatorExpressionPrefix(Position, 3, 346 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule349(-> )
  'rule' CustomRule349(-> ):
    "layout"
  'rule' CustomRule349(-> ):
'nonterm' CustomRule348(-> INT)
  'rule' CustomRule348(-> Sentinal):
    "the" @(-> Position) CustomRule349(-> ) "bounds" "of" "text" Expression(-> Mark0) "with"
    PushOperatorExpressionPrefix(Position, 3, 348 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule350(-> INT)
  'rule' CustomRule350(-> Sentinal):
    "the" @(-> Position) "italic" "of"
    PushOperatorExpressionPrefix(Position, 3, 350 -> Sentinal)
'nonterm' CustomRule351(-> INT)
  'rule' CustomRule351(-> Sentinal):
    "the" @(-> Position) "bold" "of"
    PushOperatorExpressionPrefix(Position, 3, 351 -> Sentinal)
'nonterm' CustomRule352(-> INT)
  'rule' CustomRule352(-> Sentinal):
    "the" @(-> Position) "name" "of"
    PushOperatorExpressionPrefix(Position, 3, 352 -> Sentinal)
'nonterm' CustomRule354(-> EXPRESSION, EXPRESSION)
  'rule' CustomRule354(-> Mark1, Mark2):
    "bold" @(-> Position)  
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark1)
    where(EXPRESSION'false(UndefinedPosition) -> Mark2)
  'rule' CustomRule354(-> Mark1, Mark2):
    "italic" @(-> Position)  
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark1)
    where(EXPRESSION'true(UndefinedPosition) -> Mark2)
  'rule' CustomRule354(-> Mark1, Mark2):
    "bold" @(-> Position) "italic"  
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark1)
    where(EXPRESSION'true(UndefinedPosition) -> Mark2)
'nonterm' CustomRule353(-> INT)
  'rule' CustomRule353(-> Sentinal):
    "font" @(-> Position) Expression(-> Mark0) "with" CustomRule354(-> Mark1, Mark2) "style" "at" "size"
    PushOperatorExpressionPrefix(Position, 13, 353 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
    PushOperatorExpressionArgument(Mark2 -> _)
'nonterm' CustomRule356(-> EXPRESSION, EXPRESSION)
  'rule' CustomRule356(-> Mark1, Mark2):
    "bold" @(-> Position)  
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark1)
    where(EXPRESSION'false(UndefinedPosition) -> Mark2)
  'rule' CustomRule356(-> Mark1, Mark2):
    "italic" @(-> Position)  
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark1)
    where(EXPRESSION'true(UndefinedPosition) -> Mark2)
  'rule' CustomRule356(-> Mark1, Mark2):
    "bold" @(-> Position) "italic"  
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark1)
    where(EXPRESSION'true(UndefinedPosition) -> Mark2)
'nonterm' CustomRule355(-> EXPRESSION)
  'rule' CustomRule355(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, nil))))):
    "font" @(-> Position) Expression(-> Mark0) "with" CustomRule356(-> Mark1, Mark2) "style"
    CustomInvokeLists(355 -> Invoke)
'nonterm' CustomRule357(-> INT)
  'rule' CustomRule357(-> Sentinal):
    "font" @(-> Position) Expression(-> Mark0)   "at" "size"
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark1)
    where(EXPRESSION'false(UndefinedPosition) -> Mark2)
    PushOperatorExpressionPrefix(Position, 13, 357 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
    PushOperatorExpressionArgument(Mark2 -> _)
'nonterm' CustomRule358(-> INT)
  'rule' CustomRule358(-> Sentinal):
    "font" @(-> Position)
    PushOperatorExpressionPrefix(Position, 13, 358 -> Sentinal)
'nonterm' CustomRule359(-> INT)
  'rule' CustomRule359(-> Sentinal):
    "the" @(-> Position) "source" "of"
    PushOperatorExpressionPrefix(Position, 3, 359 -> Sentinal)
'nonterm' CustomRule360(-> INT)
  'rule' CustomRule360(-> Sentinal):
    "the" @(-> Position) "knockout" "of"
    PushOperatorExpressionPrefix(Position, 3, 360 -> Sentinal)
'nonterm' CustomRule361(-> INT)
  'rule' CustomRule361(-> Sentinal):
    "the" @(-> Position) "angle" "of"
    PushOperatorExpressionPrefix(Position, 3, 361 -> Sentinal)
'nonterm' CustomRule362(-> INT)
  'rule' CustomRule362(-> Sentinal):
    "the" @(-> Position) "distance" "of"
    PushOperatorExpressionPrefix(Position, 3, 362 -> Sentinal)
'nonterm' CustomRule363(-> INT)
  'rule' CustomRule363(-> Sentinal):
    "the" @(-> Position) "spread" "of"
    PushOperatorExpressionPrefix(Position, 3, 363 -> Sentinal)
'nonterm' CustomRule364(-> INT)
  'rule' CustomRule364(-> Sentinal):
    "the" @(-> Position) "size" "of"
    PushOperatorExpressionPrefix(Position, 3, 364 -> Sentinal)
'nonterm' CustomRule365(-> INT)
  'rule' CustomRule365(-> Sentinal):
    "the" @(-> Position) "blend" "mode" "of"
    PushOperatorExpressionPrefix(Position, 3, 365 -> Sentinal)
'nonterm' CustomRule366(-> INT)
  'rule' CustomRule366(-> Sentinal):
    Custom_EffectType(-> Mark0) @(-> Position) "effect" "with" "properties"
    PushOperatorExpressionPrefix(Position, 13, 366 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule367(-> EXPRESSION)
  'rule' CustomRule367(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    Custom_EffectType(-> Mark0) @(-> Position) "effect"
    CustomInvokeLists(367 -> Invoke)
'nonterm' CustomRule368(-> EXPRESSION)
  'rule' CustomRule368(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "color" @(-> Position) "overlay" 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 0) -> Mark0)
    CustomInvokeLists(368 -> Invoke)
  'rule' CustomRule368(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "inner" @(-> Position) "shadow" 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 1) -> Mark0)
    CustomInvokeLists(368 -> Invoke)
  'rule' CustomRule368(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "outer" @(-> Position) "shadow" 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 2) -> Mark0)
    CustomInvokeLists(368 -> Invoke)
  'rule' CustomRule368(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "inner" @(-> Position) "glow" 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 3) -> Mark0)
    CustomInvokeLists(368 -> Invoke)
  'rule' CustomRule368(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "outer" @(-> Position) "glow" 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 4) -> Mark0)
    CustomInvokeLists(368 -> Invoke)
'nonterm' Custom_EffectType(-> EXPRESSION)
  'rule' Custom_EffectType(-> Expr):
    CustomRule368(-> Expr)
'nonterm' CustomRule369(-> STATEMENT)
  'rule' CustomRule369(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "close" @(-> Position) "path" "on" Expression(-> Mark0)
    CustomInvokeLists(369 -> Invoke)
'nonterm' CustomRule370(-> STATEMENT)
  'rule' CustomRule370(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, expressionlist(Mark3, nil)))))):
    "arc" @(-> Position) "to" Expression(-> Mark0) "with" "radii" Expression(-> Mark1) "rotated" "by" Expression(-> Mark2) "on" Expression(-> Mark3)
    CustomInvokeLists(370 -> Invoke)
'nonterm' CustomRule372(-> EXPRESSION)
  'rule' CustomRule372(-> Mark3):
    "largest" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark3)
  'rule' CustomRule372(-> Mark3):
    "smallest" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark3)
'nonterm' CustomRule373(-> EXPRESSION)
  'rule' CustomRule373(-> Mark4):
    "clockwise" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark4)
  'rule' CustomRule373(-> Mark4):
    "anticlockwise" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark4)
'nonterm' CustomRule371(-> STATEMENT)
  'rule' CustomRule371(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, expressionlist(Mark3, expressionlist(Mark4, expressionlist(Mark5, nil)))))))):
    "arc" @(-> Position) "to" Expression(-> Mark0) "with" "radii" Expression(-> Mark1) "rotated" "by" Expression(-> Mark2) "taking" CustomRule372(-> Mark3) CustomRule373(-> Mark4) "route" "on" Expression(-> Mark5)
    CustomInvokeLists(371 -> Invoke)
'nonterm' CustomRule374(-> STATEMENT)
  'rule' CustomRule374(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, expressionlist(Mark3, nil)))))):
    "arc" @(-> Position) "through" Expression(-> Mark0) "to" Expression(-> Mark1) "with" "radius" Expression(-> Mark2) "on" Expression(-> Mark3)
    CustomInvokeLists(374 -> Invoke)
'nonterm' CustomRule376(-> EXPRESSION)
  'rule' CustomRule376(-> Mark1):
    "then" @(-> Position) Expression(-> Mark1)
  'rule' CustomRule376(-> Mark1):
    where(EXPRESSION'nil -> Mark1)
'nonterm' CustomRule375(-> STATEMENT)
  'rule' CustomRule375(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, expressionlist(Mark2, expressionlist(Mark3, nil)))))):
    "curve" @(-> Position) "through" Expression(-> Mark0) CustomRule376(-> Mark1) "to" Expression(-> Mark2) "on" Expression(-> Mark3)
    CustomInvokeLists(375 -> Invoke)
'nonterm' CustomRule377(-> STATEMENT)
  'rule' CustomRule377(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "line" @(-> Position) "to" Expression(-> Mark0) "on" Expression(-> Mark1)
    CustomInvokeLists(377 -> Invoke)
'nonterm' CustomRule378(-> STATEMENT)
  'rule' CustomRule378(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "move" @(-> Position) "to" Expression(-> Mark0) "on" Expression(-> Mark1)
    CustomInvokeLists(378 -> Invoke)
'nonterm' CustomRule379(-> INT)
  'rule' CustomRule379(-> Sentinal):
    "the" @(-> Position) "instructions" "of"
    PushOperatorExpressionPrefix(Position, 3, 379 -> Sentinal)
'nonterm' CustomRule380(-> INT)
  'rule' CustomRule380(-> Sentinal):
    "the" @(-> Position) "bounding" "box" "of"
    PushOperatorExpressionPrefix(Position, 3, 380 -> Sentinal)
'nonterm' CustomRule382(-> EXPRESSION)
  'rule' CustomRule382(-> Mark1):
    "to" @(-> Position) Expression(-> Mark1)
  'rule' CustomRule382(-> Mark1):
    where(EXPRESSION'nil -> Mark1)
'nonterm' CustomRule381(-> INT)
  'rule' CustomRule381(-> Sentinal):
    "subpath" @(-> Position) Expression(-> Mark0) CustomRule382(-> Mark1) "of"
    PushOperatorExpressionPrefix(Position, 3, 381 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
'nonterm' CustomRule384(-> EXPRESSION, EXPRESSION)
  'rule' CustomRule384(-> Mark1, Mark2):
    "radius" @(-> Position) Expression(-> Mark1)
    where(EXPRESSION'nil -> Mark2)
  'rule' CustomRule384(-> Mark1, Mark2):
    "radii" @(-> Position) Expression(-> Mark2)
    where(EXPRESSION'nil -> Mark1)
  'rule' CustomRule384(-> Mark1, Mark2):
    where(EXPRESSION'nil -> Mark1)
    where(EXPRESSION'nil -> Mark2)
'nonterm' CustomRule383(-> INT)
  'rule' CustomRule383(-> Sentinal):
    "segment" @(-> Position) "path" "centered" "at" Expression(-> Mark0) "with" CustomRule384(-> Mark1, Mark2) "from" Expression(-> Mark3) "to"
    PushOperatorExpressionPrefix(Position, 13, 383 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
    PushOperatorExpressionArgument(Mark2 -> _)
    PushOperatorExpressionArgument(Mark3 -> _)
'nonterm' CustomRule386(-> EXPRESSION, EXPRESSION)
  'rule' CustomRule386(-> Mark1, Mark2):
    "radius" @(-> Position) Expression(-> Mark1)
    where(EXPRESSION'nil -> Mark2)
  'rule' CustomRule386(-> Mark1, Mark2):
    "radii" @(-> Position) Expression(-> Mark2)
    where(EXPRESSION'nil -> Mark1)
  'rule' CustomRule386(-> Mark1, Mark2):
    where(EXPRESSION'nil -> Mark1)
    where(EXPRESSION'nil -> Mark2)
'nonterm' CustomRule385(-> INT)
  'rule' CustomRule385(-> Sentinal):
    "sector" @(-> Position) "path" "centered" "at" Expression(-> Mark0) "with" CustomRule386(-> Mark1, Mark2) "from" Expression(-> Mark3) "to"
    PushOperatorExpressionPrefix(Position, 13, 385 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
    PushOperatorExpressionArgument(Mark2 -> _)
    PushOperatorExpressionArgument(Mark3 -> _)
'nonterm' CustomRule388(-> EXPRESSION, EXPRESSION)
  'rule' CustomRule388(-> Mark1, Mark2):
    "radius" @(-> Position) Expression(-> Mark1)
    where(EXPRESSION'nil -> Mark2)
  'rule' CustomRule388(-> Mark1, Mark2):
    "radii" @(-> Position) Expression(-> Mark2)
    where(EXPRESSION'nil -> Mark1)
  'rule' CustomRule388(-> Mark1, Mark2):
    where(EXPRESSION'nil -> Mark1)
    where(EXPRESSION'nil -> Mark2)
'nonterm' CustomRule387(-> INT)
  'rule' CustomRule387(-> Sentinal):
    "arc" @(-> Position) "path" "centered" "at" Expression(-> Mark0) "with" CustomRule388(-> Mark1, Mark2) "from" Expression(-> Mark3) "to"
    PushOperatorExpressionPrefix(Position, 13, 387 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
    PushOperatorExpressionArgument(Mark1 -> _)
    PushOperatorExpressionArgument(Mark2 -> _)
    PushOperatorExpressionArgument(Mark3 -> _)
'nonterm' CustomRule390(-> EXPRESSION)
  'rule' CustomRule390(-> Mark0):
    "polygon" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'true(UndefinedPosition) -> Mark0)
  'rule' CustomRule390(-> Mark0):
    "polyline" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'false(UndefinedPosition) -> Mark0)
'nonterm' CustomRule389(-> INT)
  'rule' CustomRule389(-> Sentinal):
    CustomRule390(-> Mark0) @(-> Position) "path" "with" "points"
    PushOperatorExpressionPrefix(Position, 13, 389 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule391(-> INT)
  'rule' CustomRule391(-> Sentinal):
    "line" @(-> Position) "path" "from" Expression(-> Mark0) "to"
    PushOperatorExpressionPrefix(Position, 13, 391 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule392(-> INT)
  'rule' CustomRule392(-> Sentinal):
    "ellipse" @(-> Position) "path" "centered" "at" Expression(-> Mark0) "with" "radii"
    PushOperatorExpressionPrefix(Position, 13, 392 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule393(-> INT)
  'rule' CustomRule393(-> Sentinal):
    "circle" @(-> Position) "path" "centered" "at" Expression(-> Mark0) "with" "radius"
    PushOperatorExpressionPrefix(Position, 13, 393 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule394(-> INT)
  'rule' CustomRule394(-> Sentinal):
    "rectangle" @(-> Position) "path" "of"
    PushOperatorExpressionPrefix(Position, 13, 394 -> Sentinal)
'nonterm' CustomRule395(-> INT)
  'rule' CustomRule395(-> Sentinal):
    "rounded" @(-> Position) "rectangle" "path" "of" Expression(-> Mark0) "with" "radii"
    PushOperatorExpressionPrefix(Position, 13, 395 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule396(-> INT)
  'rule' CustomRule396(-> Sentinal):
    "rounded" @(-> Position) "rectangle" "path" "of" Expression(-> Mark0) "with" "radius"
    PushOperatorExpressionPrefix(Position, 13, 396 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule397(-> INT)
  'rule' CustomRule397(-> Sentinal):
    "path" @(-> Position)
    PushOperatorExpressionPrefix(Position, 13, 397 -> Sentinal)
'nonterm' CustomRule398(-> EXPRESSION)
  'rule' CustomRule398(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "empty" "path"
    CustomInvokeLists(398 -> Invoke)
'nonterm' CustomRule399(-> INT)
  'rule' CustomRule399(-> Sentinal):
    "the" @(-> Position) "pixels" "of"
    PushOperatorExpressionPrefix(Position, 3, 399 -> Sentinal)
'nonterm' CustomRule400(-> INT)
  'rule' CustomRule400(-> Sentinal):
    "the" @(-> Position) "density" "of"
    PushOperatorExpressionPrefix(Position, 3, 400 -> Sentinal)
'nonterm' CustomRule401(-> INT)
  'rule' CustomRule401(-> Sentinal):
    "the" @(-> Position) "metadata" "of"
    PushOperatorExpressionPrefix(Position, 3, 401 -> Sentinal)
'nonterm' CustomRule402(-> INT)
  'rule' CustomRule402(-> Sentinal):
    "image" @(-> Position) "of" "size" Expression(-> Mark0) "with" "pixels"
    PushOperatorExpressionPrefix(Position, 13, 402 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule403(-> INT)
  'rule' CustomRule403(-> Sentinal):
    "image" @(-> Position) "from" "data"
    PushOperatorExpressionPrefix(Position, 13, 403 -> Sentinal)
'nonterm' CustomRule404(-> INT)
  'rule' CustomRule404(-> Sentinal):
    "image" @(-> Position) "from" "resource" "file"
    PushOperatorExpressionPrefix(Position, 13, 404 -> Sentinal)
'nonterm' CustomRule405(-> INT)
  'rule' CustomRule405(-> Sentinal):
    "image" @(-> Position) "from" "file"
    PushOperatorExpressionPrefix(Position, 13, 405 -> Sentinal)
'nonterm' CustomRule406(-> STATEMENT)
  'rule' CustomRule406(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "add" @(-> Position) Expression(-> Mark0) "to" Expression(-> Mark1)
    CustomInvokeLists(406 -> Invoke)
'nonterm' CustomRule407(-> INT)
  'rule' CustomRule407(-> Sentinal):
    "the" @(-> Position) "via" "of"
    PushOperatorExpressionPrefix(Position, 3, 407 -> Sentinal)
'nonterm' CustomRule408(-> INT)
  'rule' CustomRule408(-> Sentinal):
    "the" @(-> Position) "to" "of"
    PushOperatorExpressionPrefix(Position, 3, 408 -> Sentinal)
'nonterm' CustomRule409(-> INT)
  'rule' CustomRule409(-> Sentinal):
    "the" @(-> Position) "from" "of"
    PushOperatorExpressionPrefix(Position, 3, 409 -> Sentinal)
'nonterm' CustomRule410(-> INT)
  'rule' CustomRule410(-> Sentinal):
    "the" @(-> Position) "mirror" "of"
    PushOperatorExpressionPrefix(Position, 3, 410 -> Sentinal)
'nonterm' CustomRule411(-> INT)
  'rule' CustomRule411(-> Sentinal):
    "the" @(-> Position) "wrap" "of"
    PushOperatorExpressionPrefix(Position, 3, 411 -> Sentinal)
'nonterm' CustomRule412(-> INT)
  'rule' CustomRule412(-> Sentinal):
    "the" @(-> Position) "repeat" "of"
    PushOperatorExpressionPrefix(Position, 3, 412 -> Sentinal)
'nonterm' CustomRule413(-> INT)
  'rule' CustomRule413(-> Sentinal):
    "the" @(-> Position) "type" "of"
    PushOperatorExpressionPrefix(Position, 3, 413 -> Sentinal)
'nonterm' CustomRule414(-> INT)
  'rule' CustomRule414(-> Sentinal):
    "the" @(-> Position) "ramp" "of"
    PushOperatorExpressionPrefix(Position, 3, 414 -> Sentinal)
'nonterm' CustomRule415(-> INT)
  'rule' CustomRule415(-> Sentinal):
    "the" @(-> Position) "offset" "of"
    PushOperatorExpressionPrefix(Position, 3, 415 -> Sentinal)
'nonterm' CustomRule416(-> INT)
  'rule' CustomRule416(-> Sentinal):
    Custom_GradientType(-> Mark0) @(-> Position) "gradient" "with" "ramp"
    PushOperatorExpressionPrefix(Position, 13, 416 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule417(-> INT)
  'rule' CustomRule417(-> Sentinal):
    "gradient" @(-> Position) "stop" "at" Expression(-> Mark0) "with"
    PushOperatorExpressionPrefix(Position, 13, 417 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule418(-> EXPRESSION)
  'rule' CustomRule418(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "linear" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 0) -> Mark0)
    CustomInvokeLists(418 -> Invoke)
  'rule' CustomRule418(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "radial" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 1) -> Mark0)
    CustomInvokeLists(418 -> Invoke)
  'rule' CustomRule418(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "conical" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 2) -> Mark0)
    CustomInvokeLists(418 -> Invoke)
  'rule' CustomRule418(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "diamond" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 3) -> Mark0)
    CustomInvokeLists(418 -> Invoke)
  'rule' CustomRule418(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "spiral" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 4) -> Mark0)
    CustomInvokeLists(418 -> Invoke)
  'rule' CustomRule418(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "xy" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 5) -> Mark0)
    CustomInvokeLists(418 -> Invoke)
  'rule' CustomRule418(-> invoke(Position, Invoke, expressionlist(Mark0, nil))):
    "sqrtxy" @(-> Position) 
    GetUndefinedPosition(-> UndefinedPosition)
    where(EXPRESSION'unsignedinteger(UndefinedPosition, 6) -> Mark0)
    CustomInvokeLists(418 -> Invoke)
'nonterm' Custom_GradientType(-> EXPRESSION)
  'rule' Custom_GradientType(-> Expr):
    CustomRule418(-> Expr)
'nonterm' CustomRule419(-> STATEMENT)
  'rule' CustomRule419(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "transform" @(-> Position) Expression(-> Mark0) "by" Expression(-> Mark1)
    CustomInvokeLists(419 -> Invoke)
'nonterm' CustomRule420(-> INT)
  'rule' CustomRule420(-> Sentinal):
    "the" @(-> Position) "transform" "of"
    PushOperatorExpressionPrefix(Position, 3, 420 -> Sentinal)
'nonterm' CustomRule421(-> INT)
  'rule' CustomRule421(-> Sentinal):
    "the" @(-> Position) "image" "of"
    PushOperatorExpressionPrefix(Position, 3, 421 -> Sentinal)
'nonterm' CustomRule422(-> INT)
  'rule' CustomRule422(-> Sentinal):
    "pattern" @(-> Position) "with" Expression(-> Mark0) "rotated" "by"
    PushOperatorExpressionPrefix(Position, 13, 422 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule423(-> INT)
  'rule' CustomRule423(-> Sentinal):
    "pattern" @(-> Position) "with" Expression(-> Mark0) "translated" "by"
    PushOperatorExpressionPrefix(Position, 13, 423 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule424(-> INT)
  'rule' CustomRule424(-> Sentinal):
    "pattern" @(-> Position) "with" Expression(-> Mark0) "scaled" "by"
    PushOperatorExpressionPrefix(Position, 13, 424 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule425(-> INT)
  'rule' CustomRule425(-> Sentinal):
    "pattern" @(-> Position) "with" Expression(-> Mark0) "transformed" "by"
    PushOperatorExpressionPrefix(Position, 13, 425 -> Sentinal)
    PushOperatorExpressionArgument(Mark0 -> _)
'nonterm' CustomRule426(-> INT)
  'rule' CustomRule426(-> Sentinal):
    "pattern" @(-> Position) "with"
    PushOperatorExpressionPrefix(Position, 13, 426 -> Sentinal)
'nonterm' CustomRule427(-> INT)
  'rule' CustomRule427(-> Sentinal):
    "the" @(-> Position) "color" "of"
    PushOperatorExpressionPrefix(Position, 3, 427 -> Sentinal)
'nonterm' CustomRule428(-> INT)
  'rule' CustomRule428(-> Sentinal):
    "solid" @(-> Position) "paint" "with"
    PushOperatorExpressionPrefix(Position, 13, 428 -> Sentinal)
'nonterm' CustomRule429(-> INT)
  'rule' CustomRule429(-> Sentinal):
    "*" @(-> Position)
    PushOperatorExpressionLeftBinary(Position, 7, 429 -> Sentinal)
'nonterm' CustomRule430(-> STATEMENT)
  'rule' CustomRule430(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "translate" @(-> Position) Expression(-> Mark0) "by" Expression(-> Mark1)
    CustomInvokeLists(430 -> Invoke)
'nonterm' CustomRule431(-> STATEMENT)
  'rule' CustomRule431(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "rotate" @(-> Position) Expression(-> Mark0) "by" Expression(-> Mark1)
    CustomInvokeLists(431 -> Invoke)
'nonterm' CustomRule432(-> STATEMENT)
  'rule' CustomRule432(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "skew" @(-> Position) Expression(-> Mark0) "by" Expression(-> Mark1)
    CustomInvokeLists(432 -> Invoke)
'nonterm' CustomRule433(-> STATEMENT)
  'rule' CustomRule433(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "scale" @(-> Position) Expression(-> Mark0) "by" Expression(-> Mark1)
    CustomInvokeLists(433 -> Invoke)
'nonterm' CustomRule434(-> STATEMENT)
  'rule' CustomRule434(-> invoke(Position, Invoke, expressionlist(Mark0, expressionlist(Mark1, nil)))):
    "concat" @(-> Position) Expression(-> Mark0) "with" Expression(-> Mark1)
    CustomInvokeLists(434 -> Invoke)
'nonterm' CustomRule435(-> INT)
  'rule' CustomRule435(-> Sentinal):
    "the" @(-> Position) "inverse" "of"
    PushOperatorExpressionPrefix(Position, 3, 435 -> Sentinal)
'nonterm' CustomRule436(-> INT)
  'rule' CustomRule436(-> Sentinal):
    "the" @(-> Position) "matrix" "of"
    PushOperatorExpressionPrefix(Position, 3, 436 -> Sentinal)
'nonterm' CustomRule437(-> INT)
  'rule' CustomRule437(-> Sentinal):
    "the" @(-> Position) "translation" "of"
    PushOperatorExpressionPrefix(Position, 3, 437 -> Sentinal)
'nonterm' CustomRule438(-> INT)
  'rule' CustomRule438(-> Sentinal):
    "the" @(-> Position) "skew" "of"
    PushOperatorExpressionPrefix(Position, 3, 438 -> Sentinal)
'nonterm' CustomRule439(-> INT)
  'rule' CustomRule439(-> Sentinal):
    "the" @(-> Position) "rotation" "of"
    PushOperatorExpressionPrefix(Position, 3, 439 -> Sentinal)
'nonterm' CustomRule440(-> INT)
  'rule' CustomRule440(-> Sentinal):
    "the" @(-> Position) "scale" "of"
    PushOperatorExpressionPrefix(Position, 3, 440 -> Sentinal)
'nonterm' CustomRule441(-> INT)
  'rule' CustomRule441(-> Sentinal):
    "transform" @(-> Position) "with" "matrix"
    PushOperatorExpressionPrefix(Position, 13, 441 -> Sentinal)
'nonterm' CustomRule442(-> INT)
  'rule' CustomRule442(-> Sentinal):
    "transform" @(-> Position) "with" "translation"
    PushOperatorExpressionPrefix(Position, 13, 442 -> Sentinal)
'nonterm' CustomRule443(-> INT)
  'rule' CustomRule443(-> Sentinal):
    "transform" @(-> Position) "with" "rotation" "by"
    PushOperatorExpressionPrefix(Position, 13, 443 -> Sentinal)
'nonterm' CustomRule444(-> INT)
  'rule' CustomRule444(-> Sentinal):
    "transform" @(-> Position) "with" "skew"
    PushOperatorExpressionPrefix(Position, 13, 444 -> Sentinal)
'nonterm' CustomRule445(-> INT)
  'rule' CustomRule445(-> Sentinal):
    "transform" @(-> Position) "with" "scale"
    PushOperatorExpressionPrefix(Position, 13, 445 -> Sentinal)
'nonterm' CustomRule446(-> EXPRESSION)
  'rule' CustomRule446(-> invoke(Position, Invoke, nil)):
    "the" @(-> Position) "identity" "transform"
    CustomInvokeLists(446 -> Invoke)
'nonterm' CustomRule447(-> INT)
  'rule' CustomRule447(-> Sentinal):
    "the" @(-> Position) "alpha" "of"
    PushOperatorExpressionPrefix(Position, 3, 447 -> Sentinal)
'nonterm' CustomRule448(-> INT)
  'rule' CustomRule448(-> Sentinal):
    "the" @(-> Position) "blue" "of"
    PushOperatorExpressionPrefix(Position, 3, 448 -> Sentinal)
'nonterm' CustomRule449(-> INT)
  'rule' CustomRule449(-> Sentinal):
    "the" @(-> Position) "green" "of"
    PushOperatorExpressionPrefix(Position, 3, 449 -> Sentinal)
'nonterm' CustomRule450(-> INT)
  'rule' CustomRule450(-> Sentinal):
    "the" @(-> Position) "red" "of"
    PushOperatorExpressionPrefix(Position, 3, 450 -> Sentinal)
'nonterm' CustomRule451(-> INT)
  'rule' CustomRule451(-> Sentinal):
    "color" @(-> Position)
    PushOperatorExpressionPrefix(Position, 13, 451 -> Sentinal)
'nonterm' CustomRule452(-> INT)
  'rule' CustomRule452(-> Sentinal):
    "point" @(-> Position)
    PushOperatorExpressionPrefix(Position, 3, 452 -> Sentinal)
'nonterm' CustomRule453(-> INT)
  'rule' CustomRule453(-> Sentinal):
    "the" @(-> Position) "height" "of"
    PushOperatorExpressionPrefix(Position, 3, 453 -> Sentinal)
'nonterm' CustomRule454(-> INT)
  'rule' CustomRule454(-> Sentinal):
    "the" @(-> Position) "width" "of"
    PushOperatorExpressionPrefix(Position, 3, 454 -> Sentinal)
'nonterm' CustomRule455(-> INT)
  'rule' CustomRule455(-> Sentinal):
    "the" @(-> Position) "bottom" "of"
    PushOperatorExpressionPrefix(Position, 3, 455 -> Sentinal)
'nonterm' CustomRule456(-> INT)
  'rule' CustomRule456(-> Sentinal):
    "the" @(-> Position) "right" "of"
    PushOperatorExpressionPrefix(Position, 3, 456 -> Sentinal)
'nonterm' CustomRule457(-> INT)
  'rule' CustomRule457(-> Sentinal):
    "the" @(-> Position) "y" "of"
    PushOperatorExpressionPrefix(Position, 3, 457 -> Sentinal)
'nonterm' CustomRule458(-> INT)
  'rule' CustomRule458(-> Sentinal):
    "the" @(-> Position) "top" "of"
    PushOperatorExpressionPrefix(Position, 3, 458 -> Sentinal)
'nonterm' CustomRule459(-> INT)
  'rule' CustomRule459(-> Sentinal):
    "the" @(-> Position) "x" "of"
    PushOperatorExpressionPrefix(Position, 3, 459 -> Sentinal)
'nonterm' CustomRule460(-> INT)
  'rule' CustomRule460(-> Sentinal):
    "the" @(-> Position) "left" "of"
    PushOperatorExpressionPrefix(Position, 3, 460 -> Sentinal)
'nonterm' CustomRule461(-> INT)
  'rule' CustomRule461(-> Sentinal):
    "rectangle" @(-> Position)
    PushOperatorExpressionPrefix(Position, 13, 461 -> Sentinal)
'nonterm' CustomStatements(-> STATEMENT)
  'rule' CustomStatements(-> Node):
    CustomRule0(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule1(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule2(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule3(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule4(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule5(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule6(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule7(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule8(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule9(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule10(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule11(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule12(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule13(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule24(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule27(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule35(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule36(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule39(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule40(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule41(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule42(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule43(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule44(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule45(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule46(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule47(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule48(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule49(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule54(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule78(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule82(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule83(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule84(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule85(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule86(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule87(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule88(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule89(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule94(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule96(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule101(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule102(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule103(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule115(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule116(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule117(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule118(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule128(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule129(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule130(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule131(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule139(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule142(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule143(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule144(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule145(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule174(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule175(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule176(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule178(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule183(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule192(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule194(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule196(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule212(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule213(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule214(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule218(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule228(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule229(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule231(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule233(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule238(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule241(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule243(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule271(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule274(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule275(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule276(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule277(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule287(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule289(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule295(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule298(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule307(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule313(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule314(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule315(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule316(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule318(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule319(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule321(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule323(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule324(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule325(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule327(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule328(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule369(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule370(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule371(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule374(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule375(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule377(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule378(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule406(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule419(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule430(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule431(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule432(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule433(-> Node)
  'rule' CustomStatements(-> Node):
    CustomRule434(-> Node)
'nonterm' CustomIterators(-> EXPRESSION)
  'rule' CustomIterators(-> Node):
    CustomRule108(-> Node)
  'rule' CustomIterators(-> Node):
    CustomRule125(-> Node)
  'rule' CustomIterators(-> Node):
    CustomRule141(-> Node)
  'rule' CustomIterators(-> Node):
    CustomRule180(-> Node)
  'rule' CustomIterators(-> Node):
    CustomRule181(-> Node)
'nonterm' CustomTerms(-> EXPRESSION)
  'rule' CustomTerms(-> Node):
    CustomRule22(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule23(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule25(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule26(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule29(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule30(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule31(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule37(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule38(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule55(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule64(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule81(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule105(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule106(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule107(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule126(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule172(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule182(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule221(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule235(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule236(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule237(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule240(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule246(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule248(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule249(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule250(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule251(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule253(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule255(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule257(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule259(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule260(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule262(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule263(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule264(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule265(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule266(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule267(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule268(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule269(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule270(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule273(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule279(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule282(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule283(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule284(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule285(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule286(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule292(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule293(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule294(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule312(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule355(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule367(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule398(-> Node)
  'rule' CustomTerms(-> Node):
    CustomRule446(-> Node)
'nonterm' CustomBinaryOperators(-> INT)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule34(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule56(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule57(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule58(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule77(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule127(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule150(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule151(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule152(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule169(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule170(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule171(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule173(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule185(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule187(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule198(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule199(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule200(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule201(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule202(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule203(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule204(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule205(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule206(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule207(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule208(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule209(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule244(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule245(-> Sentinal)
  'rule' CustomBinaryOperators(-> Sentinal):
    CustomRule429(-> Sentinal)
'nonterm' CustomPrefixOperators(-> INT)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule32(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule33(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule51(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule52(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule53(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule59(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule60(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule61(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule62(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule63(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule65(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule66(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule67(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule68(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule69(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule70(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule71(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule72(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule73(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule74(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule75(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule76(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule80(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule90(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule91(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule92(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule93(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule98(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule99(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule100(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule104(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule109(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule111(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule113(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule119(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule120(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule121(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule122(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule123(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule124(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule132(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule133(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule134(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule135(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule136(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule137(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule138(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule146(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule147(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule148(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule149(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule153(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule155(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule157(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule159(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule161(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule163(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule165(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule168(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule189(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule190(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule191(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule210(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule211(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule215(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule216(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule222(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule223(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule224(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule225(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule226(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule227(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule234(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule247(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule302(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule303(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule304(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule308(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule309(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule310(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule311(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule329(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule330(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule331(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule332(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule333(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule334(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule335(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule336(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule337(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule338(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule339(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule340(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule341(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule342(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule344(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule345(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule346(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule348(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule350(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule351(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule352(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule353(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule357(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule358(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule359(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule360(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule361(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule362(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule363(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule364(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule365(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule366(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule379(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule380(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule381(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule383(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule385(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule387(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule389(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule391(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule392(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule393(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule394(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule395(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule396(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule397(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule399(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule400(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule401(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule402(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule403(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule404(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule405(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule407(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule408(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule409(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule410(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule411(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule412(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule413(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule414(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule415(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule416(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule417(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule420(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule421(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule422(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule423(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule424(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule425(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule426(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule427(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule428(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule435(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule436(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule437(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule438(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule439(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule440(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule441(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule442(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule443(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule444(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule445(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule447(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule448(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule449(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule450(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule451(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule452(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule453(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule454(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule455(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule456(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule457(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule458(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule459(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule460(-> Sentinal)
  'rule' CustomPrefixOperators(-> Sentinal):
    CustomRule461(-> Sentinal)
'nonterm' CustomPostfixOperators(-> INT)
  'rule' CustomPostfixOperators(-> Sentinal):
    CustomRule14(-> Sentinal)
  'rule' CustomPostfixOperators(-> Sentinal):
    CustomRule15(-> Sentinal)
  'rule' CustomPostfixOperators(-> Sentinal):
    CustomRule16(-> Sentinal)
  'rule' CustomPostfixOperators(-> Sentinal):
    CustomRule17(-> Sentinal)
  'rule' CustomPostfixOperators(-> Sentinal):
    CustomRule18(-> Sentinal)
  'rule' CustomPostfixOperators(-> Sentinal):
    CustomRule19(-> Sentinal)
  'rule' CustomPostfixOperators(-> Sentinal):
    CustomRule20(-> Sentinal)
  'rule' CustomPostfixOperators(-> Sentinal):
    CustomRule21(-> Sentinal)
  'rule' CustomPostfixOperators(-> Sentinal):
    CustomRule79(-> Sentinal)
  'rule' CustomPostfixOperators(-> Sentinal):
    CustomRule140(-> Sentinal)
  'rule' CustomPostfixOperators(-> Sentinal):
    CustomRule166(-> Sentinal)
  'rule' CustomPostfixOperators(-> Sentinal):
    CustomRule167(-> Sentinal)
  'rule' CustomPostfixOperators(-> Sentinal):
    CustomRule184(-> Sentinal)
  'rule' CustomPostfixOperators(-> Sentinal):
    CustomRule193(-> Sentinal)
  'rule' CustomPostfixOperators(-> Sentinal):
    CustomRule195(-> Sentinal)
  'rule' CustomPostfixOperators(-> Sentinal):
    CustomRule197(-> Sentinal)
  'rule' CustomPostfixOperators(-> Sentinal):
    CustomRule305(-> Sentinal)
  'rule' CustomPostfixOperators(-> Sentinal):
    CustomRule306(-> Sentinal)
'action' InitializeCustomInvokeLists()
  'rule' InitializeCustomInvokeLists():
    InitializeCustomInvokeLists_0

'action' InitializeCustomInvokeLists_0
  'rule' InitializeCustomInvokeLists_0
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_1_0)
    MakeCustomInvokeMethodList("MCUnitTestFailsDescriptionAndReason", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_1_0)
    MakeCustomInvokeList("UnitTestFailsDescriptionAndReason", "com.livecode.unittest", MethodList_1_0, List_Nil -> List_0_1)
    DefineCustomInvokeList(0, List_0_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_2_0)
    MakeCustomInvokeMethodList("MCUnitTestFailsReason", Execute_Type,   MethodListArgs_2_0, MethodList_Nil -> MethodList_2_0)
    MakeCustomInvokeList("UnitTestFailsReason", "com.livecode.unittest", MethodList_2_0, List_Nil -> List_1_1)
    DefineCustomInvokeList(1, List_1_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_3_0)
    MakeCustomInvokeMethodList("MCUnitTestFailsDescription", Execute_Type,   MethodListArgs_3_0, MethodList_Nil -> MethodList_3_0)
    MakeCustomInvokeList("UnitTestFailsDescription", "com.livecode.unittest", MethodList_3_0, List_Nil -> List_2_1)
    DefineCustomInvokeList(2, List_2_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_4_0)
    MakeCustomInvokeMethodList("MCUnitTestFails", Execute_Type,   MethodListArgs_4_0, MethodList_Nil -> MethodList_4_0)
    MakeCustomInvokeList("UnitTestFails", "com.livecode.unittest", MethodList_4_0, List_Nil -> List_3_1)
    DefineCustomInvokeList(3, List_3_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_5_0)
    MakeCustomInvokeMethodList("MCUnitTestSkipDescriptionAndReason", Execute_Type,   MethodListArgs_5_0, MethodList_Nil -> MethodList_5_0)
    MakeCustomInvokeList("UnitTestSkipDescriptionAndReason", "com.livecode.unittest", MethodList_5_0, List_Nil -> List_4_1)
    DefineCustomInvokeList(4, List_4_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_6_0)
    MakeCustomInvokeMethodList("MCUnitTestSkipReason", Execute_Type,   MethodListArgs_6_0, MethodList_Nil -> MethodList_6_0)
    MakeCustomInvokeList("UnitTestSkipReason", "com.livecode.unittest", MethodList_6_0, List_Nil -> List_5_1)
    DefineCustomInvokeList(5, List_5_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_7_0)
    MakeCustomInvokeMethodList("MCUnitTestSkipDescription", Execute_Type,   MethodListArgs_7_0, MethodList_Nil -> MethodList_7_0)
    MakeCustomInvokeList("UnitTestSkipDescription", "com.livecode.unittest", MethodList_7_0, List_Nil -> List_6_1)
    DefineCustomInvokeList(6, List_6_1)
    MakeCustomInvokeMethodList("MCUnitTestSkip", Execute_Type,  Signature_Nil, MethodList_Nil -> MethodList_8_0)
    MakeCustomInvokeList("UnitTestSkip", "com.livecode.unittest", MethodList_8_0, List_Nil -> List_7_1)
    DefineCustomInvokeList(7, List_7_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_9_0)
    MakeCustomInvokeMethodList("MCUnitTestDescription", Execute_Type,   MethodListArgs_9_0, MethodList_Nil -> MethodList_9_0)
    MakeCustomInvokeList("UnitTestDescription", "com.livecode.unittest", MethodList_9_0, List_Nil -> List_8_1)
    DefineCustomInvokeList(8, List_8_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_10_0)
    MakeCustomInvokeMethodList("MCUnitTest", Execute_Type,   MethodListArgs_10_0, MethodList_Nil -> MethodList_10_0)
    MakeCustomInvokeList("UnitTest", "com.livecode.unittest", MethodList_10_0, List_Nil -> List_9_1)
    DefineCustomInvokeList(9, List_9_1)
    InitializeCustomInvokeLists_10

'action' InitializeCustomInvokeLists_10
  'rule' InitializeCustomInvokeLists_10
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_11_0)
    MakeCustomInvokeMethodList("MCUnitDiagnostic", Execute_Type,   MethodListArgs_11_0, MethodList_Nil -> MethodList_11_0)
    MakeCustomInvokeList("UnitDiagnostic", "com.livecode.unittest", MethodList_11_0, List_Nil -> List_10_1)
    DefineCustomInvokeList(10, List_10_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_12_0)
    MakeCustomInvokeMethodList("MCUnitPlan", Execute_Type,   MethodListArgs_12_0, MethodList_Nil -> MethodList_12_0)
    MakeCustomInvokeList("UnitPlan", "com.livecode.unittest", MethodList_12_0, List_Nil -> List_11_1)
    DefineCustomInvokeList(11, List_11_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_13_0)
    MakeCustomInvokeMethodList("MCTypeConvertExecCombineListWithDelimiter", Execute_Type,   MethodListArgs_13_0, MethodList_Nil -> MethodList_13_0)
    MakeCustomInvokeList("CombineListWith", "com.livecode.typeconvert", MethodList_13_0, List_Nil -> List_12_1)
    DefineCustomInvokeList(12, List_12_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_14_0)
    MakeCustomInvokeMethodList("MCTypeConvertExecSplitStringByDelimiter", Execute_Type,   MethodListArgs_14_0, MethodList_Nil -> MethodList_14_0)
    MakeCustomInvokeList("StringSplitBy", "com.livecode.typeconvert", MethodList_14_0, List_Nil -> List_13_1)
    DefineCustomInvokeList(13, List_13_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_15_0)
    MakeCustomInvokeMethodList("MCTypeEvalIsAList", Evaluate_Type,   MethodListArgs_15_0, MethodList_Nil -> MethodList_15_0)
    MakeCustomInvokeList("IsAList", "com.livecode.type", MethodList_15_0, List_Nil -> List_14_1)
    DefineCustomInvokeList(14, List_14_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_16_0)
    MakeCustomInvokeMethodList("MCTypeEvalIsAnArray", Evaluate_Type,   MethodListArgs_16_0, MethodList_Nil -> MethodList_16_0)
    MakeCustomInvokeList("IsAnArray", "com.livecode.type", MethodList_16_0, List_Nil -> List_15_1)
    DefineCustomInvokeList(15, List_15_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_17_0)
    MakeCustomInvokeMethodList("MCTypeEvalIsAData", Evaluate_Type,   MethodListArgs_17_0, MethodList_Nil -> MethodList_17_0)
    MakeCustomInvokeList("IsAData", "com.livecode.type", MethodList_17_0, List_Nil -> List_16_1)
    DefineCustomInvokeList(16, List_16_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_18_0)
    MakeCustomInvokeMethodList("MCTypeEvalIsAString", Evaluate_Type,   MethodListArgs_18_0, MethodList_Nil -> MethodList_18_0)
    MakeCustomInvokeList("IsAString", "com.livecode.type", MethodList_18_0, List_Nil -> List_17_1)
    DefineCustomInvokeList(17, List_17_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_19_0)
    MakeCustomInvokeMethodList("MCTypeEvalIsANumber", Evaluate_Type,   MethodListArgs_19_0, MethodList_Nil -> MethodList_19_0)
    MakeCustomInvokeList("IsANumber", "com.livecode.type", MethodList_19_0, List_Nil -> List_18_1)
    DefineCustomInvokeList(18, List_18_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_20_0)
    MakeCustomInvokeMethodList("MCTypeEvalIsABoolean", Evaluate_Type,   MethodListArgs_20_0, MethodList_Nil -> MethodList_20_0)
    MakeCustomInvokeList("IsABoolean", "com.livecode.type", MethodList_20_0, List_Nil -> List_19_1)
    DefineCustomInvokeList(19, List_19_1)
    InitializeCustomInvokeLists_20

'action' InitializeCustomInvokeLists_20
  'rule' InitializeCustomInvokeLists_20
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_21_0)
    MakeCustomInvokeMethodList("MCTypeEvalIsNotEmpty", Evaluate_Type,   MethodListArgs_21_0, MethodList_Nil -> MethodList_21_0)
    MakeCustomInvokeList("IsNotEmpty", "com.livecode.type", MethodList_21_0, List_Nil -> List_20_1)
    DefineCustomInvokeList(20, List_20_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_22_0)
    MakeCustomInvokeMethodList("MCTypeEvalIsEmpty", Evaluate_Type,   MethodListArgs_22_0, MethodList_Nil -> MethodList_22_0)
    MakeCustomInvokeList("IsEmpty", "com.livecode.type", MethodList_22_0, List_Nil -> List_21_1)
    DefineCustomInvokeList(21, List_21_1)
    MakeCustomInvokeMethodList("MCSystemEvalErrorDescription", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_23_0)
    MakeCustomInvokeList("SystemErrorDescription", "com.livecode.system", MethodList_23_0, List_Nil -> List_22_1)
    DefineCustomInvokeList(22, List_22_1)
    MakeCustomInvokeMethodList("MCSystemEvalErrorCode", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_24_0)
    MakeCustomInvokeList("SystemErrorCode", "com.livecode.system", MethodList_24_0, List_Nil -> List_23_1)
    DefineCustomInvokeList(23, List_23_1)
    MakeCustomInvokeMethodList("MCSErrorReset", Execute_Type,  Signature_Nil, MethodList_Nil -> MethodList_25_0)
    MakeCustomInvokeList("ResetSystemError", "com.livecode.system", MethodList_25_0, List_Nil -> List_24_1)
    DefineCustomInvokeList(24, List_24_1)
    MakeCustomInvokeMethodList("MCSystemExecGetCommandArguments", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_26_0)
    MakeCustomInvokeList("CommandArguments", "com.livecode.system", MethodList_26_0, List_Nil -> List_25_1)
    DefineCustomInvokeList(25, List_25_1)
    MakeCustomInvokeMethodList("MCSystemExecGetCommandName", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_27_0)
    MakeCustomInvokeList("CommandName", "com.livecode.system", MethodList_27_0, List_Nil -> List_26_1)
    DefineCustomInvokeList(26, List_26_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_28_1)
    MakeCustomInvokeMethodList("MCSystemExecQuitWithStatus", Execute_Type,   MethodListArgs_28_1, MethodList_Nil -> MethodList_28_1)
    MakeCustomInvokeMethodList("MCSystemExecQuit", Execute_Type,  Signature_Nil, MethodList_28_1 -> MethodList_28_0)
    MakeCustomInvokeList("QuitWithStatus", "com.livecode.system", MethodList_28_0, List_Nil -> List_27_1)
    DefineCustomInvokeList(27, List_27_1)
    MakeCustomInvokeMethodList("MCSystemExecGetArchitecture", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_29_0)
    MakeCustomInvokeList("Architecture", "com.livecode.system", MethodList_29_0, List_Nil -> List_29_1)
    DefineCustomInvokeList(29, List_29_1)
    MakeCustomInvokeMethodList("MCSystemExecGetOperatingSystem", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_30_0)
    MakeCustomInvokeList("OperatingSystem", "com.livecode.system", MethodList_30_0, List_Nil -> List_30_1)
    DefineCustomInvokeList(30, List_30_1)
    InitializeCustomInvokeLists_30

'action' InitializeCustomInvokeLists_30
  'rule' InitializeCustomInvokeLists_30
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodList("MCStringEvalEmpty", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_31_0)
    MakeCustomInvokeList("EmptyString", "com.livecode.string", MethodList_31_0, List_Nil -> List_31_1)
    DefineCustomInvokeList(31, List_31_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_32_0)
    MakeCustomInvokeMethodList("MCStringEvalLowercaseOf", Evaluate_Type,   MethodListArgs_32_0, MethodList_Nil -> MethodList_32_0)
    MakeCustomInvokeList("LowercaseString", "com.livecode.string", MethodList_32_0, List_Nil -> List_32_1)
    DefineCustomInvokeList(32, List_32_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_33_0)
    MakeCustomInvokeMethodList("MCStringEvalUppercaseOf", Evaluate_Type,   MethodListArgs_33_0, MethodList_Nil -> MethodList_33_0)
    MakeCustomInvokeList("UppercaseString", "com.livecode.string", MethodList_33_0, List_Nil -> List_33_1)
    DefineCustomInvokeList(33, List_33_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_34_0)
    MakeCustomInvokeMethodList("MCStringEvalConcatenateWithSpace", Evaluate_Type,   MethodListArgs_34_0, MethodList_Nil -> MethodList_34_0)
    MakeCustomInvokeList("ConcatenateStringsWithSpace", "com.livecode.string", MethodList_34_0, List_Nil -> List_34_1)
    DefineCustomInvokeList(34, List_34_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, InOut_Mode, 2 -> MethodListArgs_35_0)
    MakeCustomInvokeMethodList("MCStringExecReplace", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(InOut_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_35_0)
    MakeCustomInvokeList("ReplaceString", "com.livecode.string", MethodList_35_0, List_Nil -> List_35_1)
    DefineCustomInvokeList(35, List_35_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_36_0)
    MakeCustomInvokeMethodList("MCStreamExecWriteToStream", Execute_Type,   MethodListArgs_36_0, MethodList_Nil -> MethodList_36_0)
    MakeCustomInvokeList("WriteToStream", "com.livecode.stream", MethodList_36_0, List_Nil -> List_36_1)
    DefineCustomInvokeList(36, List_36_1)
    MakeCustomInvokeMethodList("MCStreamExecGetStandardError", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_37_0)
    MakeCustomInvokeList("DefaultErrorStream", "com.livecode.stream", MethodList_37_0, List_Nil -> List_37_1)
    DefineCustomInvokeList(37, List_37_1)
    MakeCustomInvokeMethodList("MCStreamExecGetStandardOutput", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_38_0)
    MakeCustomInvokeList("DefaultOutputStream", "com.livecode.stream", MethodList_38_0, List_Nil -> List_38_1)
    DefineCustomInvokeList(38, List_38_1)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_39_0)
    MakeCustomInvokeMethodList("MCSortExecSortListUsingHandler", Execute_Type,   MethodListArgs_39_0, MethodList_Nil -> MethodList_39_0)
    MakeCustomInvokeList("SortListUsingHandler", "com.livecode.sort", MethodList_39_0, List_Nil -> List_39_1)
    DefineCustomInvokeList(39, List_39_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_40_0)
    MakeCustomInvokeMethodList("MCSortExecSortListDescendingDateTime", Execute_Type,   MethodListArgs_40_0, MethodList_Nil -> MethodList_40_0)
    MakeCustomInvokeList("SortListDescendingDateTime", "com.livecode.sort", MethodList_40_0, List_Nil -> List_40_1)
    DefineCustomInvokeList(40, List_40_1)
    InitializeCustomInvokeLists_40

'action' InitializeCustomInvokeLists_40
  'rule' InitializeCustomInvokeLists_40
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_41_0)
    MakeCustomInvokeMethodList("MCSortExecSortListAscendingDateTime", Execute_Type,   MethodListArgs_41_0, MethodList_Nil -> MethodList_41_0)
    MakeCustomInvokeList("SortListAscendingDateTime", "com.livecode.sort", MethodList_41_0, List_Nil -> List_41_1)
    DefineCustomInvokeList(41, List_41_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_42_0)
    MakeCustomInvokeMethodList("MCSortExecSortListDescendingNumeric", Execute_Type,   MethodListArgs_42_0, MethodList_Nil -> MethodList_42_0)
    MakeCustomInvokeList("SortListDescendingNumeric", "com.livecode.sort", MethodList_42_0, List_Nil -> List_42_1)
    DefineCustomInvokeList(42, List_42_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_43_0)
    MakeCustomInvokeMethodList("MCSortExecSortListAscendingNumeric", Execute_Type,   MethodListArgs_43_0, MethodList_Nil -> MethodList_43_0)
    MakeCustomInvokeList("SortListAscendingNumeric", "com.livecode.sort", MethodList_43_0, List_Nil -> List_43_1)
    DefineCustomInvokeList(43, List_43_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_44_0)
    MakeCustomInvokeMethodList("MCSortExecSortListDescendingBinary", Execute_Type,   MethodListArgs_44_0, MethodList_Nil -> MethodList_44_0)
    MakeCustomInvokeList("SortListDescendingBinary", "com.livecode.sort", MethodList_44_0, List_Nil -> List_44_1)
    DefineCustomInvokeList(44, List_44_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_45_0)
    MakeCustomInvokeMethodList("MCSortExecSortListAscendingBinary", Execute_Type,   MethodListArgs_45_0, MethodList_Nil -> MethodList_45_0)
    MakeCustomInvokeList("SortListAscendingBinary", "com.livecode.sort", MethodList_45_0, List_Nil -> List_45_1)
    DefineCustomInvokeList(45, List_45_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_46_0)
    MakeCustomInvokeMethodList("MCSortExecSortListDescendingText", Execute_Type,   MethodListArgs_46_0, MethodList_Nil -> MethodList_46_0)
    MakeCustomInvokeList("SortListDescendingText", "com.livecode.sort", MethodList_46_0, List_Nil -> List_46_1)
    DefineCustomInvokeList(46, List_46_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_47_0)
    MakeCustomInvokeMethodList("MCSortExecSortListAscendingText", Execute_Type,   MethodListArgs_47_0, MethodList_Nil -> MethodList_47_0)
    MakeCustomInvokeList("SortListAscendingText", "com.livecode.sort", MethodList_47_0, List_Nil -> List_47_1)
    DefineCustomInvokeList(47, List_47_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_48_0)
    MakeCustomInvokeMethodList("MCSortExecSortListDescending", Execute_Type,   MethodListArgs_48_0, MethodList_Nil -> MethodList_48_0)
    MakeCustomInvokeList("SortListDescending", "com.livecode.sort", MethodList_48_0, List_Nil -> List_48_1)
    DefineCustomInvokeList(48, List_48_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_49_0)
    MakeCustomInvokeMethodList("MCSortExecSortListAscending", Execute_Type,   MethodListArgs_49_0, MethodList_Nil -> MethodList_49_0)
    MakeCustomInvokeList("SortListAscending", "com.livecode.sort", MethodList_49_0, List_Nil -> List_49_1)
    DefineCustomInvokeList(49, List_49_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_50_0)
    MakeCustomInvokeMethodList("MCMathFoundationEvalCeilingNumber", Evaluate_Type,   MethodListArgs_50_0, MethodList_Nil -> MethodList_50_0)
    MakeCustomInvokeList("CeilOperator", "com.livecode.mathfoundation", MethodList_50_0, List_Nil -> List_51_1)
    DefineCustomInvokeList(51, List_51_1)
    InitializeCustomInvokeLists_50

'action' InitializeCustomInvokeLists_50
  'rule' InitializeCustomInvokeLists_50
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_51_0)
    MakeCustomInvokeMethodList("MCMathFoundationEvalFloorNumber", Evaluate_Type,   MethodListArgs_51_0, MethodList_Nil -> MethodList_51_0)
    MakeCustomInvokeList("FloorOperator", "com.livecode.mathfoundation", MethodList_51_0, List_Nil -> List_52_1)
    DefineCustomInvokeList(52, List_52_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_52_0)
    MakeCustomInvokeMethodList("MCMathFoundationEvalRoundedNumberToNearest", Evaluate_Type,   MethodListArgs_52_0, MethodList_Nil -> MethodList_52_0)
    MakeCustomInvokeList("RoundedToNearest", "com.livecode.mathfoundation", MethodList_52_0, List_Nil -> List_53_1)
    DefineCustomInvokeList(53, List_53_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_53_0)
    MakeCustomInvokeMethodList("MCMathFoundationExecRoundNumberToNearest", Execute_Type,   MethodListArgs_53_0, MethodList_Nil -> MethodList_53_0)
    MakeCustomInvokeList("RoundToNearest", "com.livecode.mathfoundation", MethodList_53_0, List_Nil -> List_54_1)
    DefineCustomInvokeList(54, List_54_1)
    MakeCustomInvokeMethodList("MCMathFoundationEvalPi", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_54_0)
    MakeCustomInvokeList("PiConstant", "com.livecode.mathfoundation", MethodList_54_0, List_Nil -> List_55_1)
    DefineCustomInvokeList(55, List_55_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_55_0)
    MakeCustomInvokeMethodList("MCMathEvalConvertBase", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_55_0)
    MakeCustomInvokeList("BaseConvert", "com.livecode.math", MethodList_55_0, List_Nil -> List_56_1)
    DefineCustomInvokeList(56, List_56_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_56_0)
    MakeCustomInvokeMethodList("MCMathEvalConvertFromBase10", Evaluate_Type,   MethodListArgs_56_0, MethodList_Nil -> MethodList_56_0)
    MakeCustomInvokeList("BaseConvertTo", "com.livecode.math", MethodList_56_0, List_Nil -> List_57_1)
    DefineCustomInvokeList(57, List_57_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_57_0)
    MakeCustomInvokeMethodList("MCMathEvalConvertToBase10", Evaluate_Type,   MethodListArgs_57_0, MethodList_Nil -> MethodList_57_0)
    MakeCustomInvokeList("BaseConvertFrom", "com.livecode.math", MethodList_57_0, List_Nil -> List_58_1)
    DefineCustomInvokeList(58, List_58_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_58_0)
    MakeCustomInvokeMethodList("MCMathEvalSqrtNumber", Evaluate_Type,   MethodListArgs_58_0, MethodList_Nil -> MethodList_58_0)
    MakeCustomInvokeList("SquareRootOperator", "com.livecode.math", MethodList_58_0, List_Nil -> List_59_1)
    DefineCustomInvokeList(59, List_59_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_59_0)
    MakeCustomInvokeMethodList("MCMathEvalMaxList", Evaluate_Type,   MethodListArgs_59_0, MethodList_Nil -> MethodList_59_0)
    MakeCustomInvokeList("MaxListOperator", "com.livecode.math", MethodList_59_0, List_Nil -> List_60_1)
    DefineCustomInvokeList(60, List_60_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_60_0)
    MakeCustomInvokeMethodList("MCMathEvalMinList", Evaluate_Type,   MethodListArgs_60_0, MethodList_Nil -> MethodList_60_0)
    MakeCustomInvokeList("MinListOperator", "com.livecode.math", MethodList_60_0, List_Nil -> List_61_1)
    DefineCustomInvokeList(61, List_61_1)
    InitializeCustomInvokeLists_60

'action' InitializeCustomInvokeLists_60
  'rule' InitializeCustomInvokeLists_60
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_61_0)
    MakeCustomInvokeMethodList("MCMathEvalMaxNumber", Evaluate_Type,   MethodListArgs_61_0, MethodList_Nil -> MethodList_61_0)
    MakeCustomInvokeList("MaxOperator", "com.livecode.math", MethodList_61_0, List_Nil -> List_62_1)
    DefineCustomInvokeList(62, List_62_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_62_0)
    MakeCustomInvokeMethodList("MCMathEvalMinNumber", Evaluate_Type,   MethodListArgs_62_0, MethodList_Nil -> MethodList_62_0)
    MakeCustomInvokeList("MinOperator", "com.livecode.math", MethodList_62_0, List_Nil -> List_63_1)
    DefineCustomInvokeList(63, List_63_1)
    MakeCustomInvokeMethodList("MCMathEvalRandomReal", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_63_0)
    MakeCustomInvokeList("RandomNumber", "com.livecode.math", MethodList_63_0, List_Nil -> List_64_1)
    DefineCustomInvokeList(64, List_64_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_64_0)
    MakeCustomInvokeMethodList("MCMathEvalAbsNumber", Evaluate_Type,   MethodListArgs_64_0, MethodList_Nil -> MethodList_64_0)
    MakeCustomInvokeList("AbsOperator", "com.livecode.math", MethodList_64_0, List_Nil -> List_65_1)
    DefineCustomInvokeList(65, List_65_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_65_0)
    MakeCustomInvokeMethodList("MCMathEvalTruncNumber", Evaluate_Type,   MethodListArgs_65_0, MethodList_Nil -> MethodList_65_0)
    MakeCustomInvokeList("TruncOperator", "com.livecode.math", MethodList_65_0, List_Nil -> List_66_1)
    DefineCustomInvokeList(66, List_66_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_66_0)
    MakeCustomInvokeMethodList("MCMathEvalExpNumber", Evaluate_Type,   MethodListArgs_66_0, MethodList_Nil -> MethodList_66_0)
    MakeCustomInvokeList("ExpOperator", "com.livecode.math", MethodList_66_0, List_Nil -> List_67_1)
    DefineCustomInvokeList(67, List_67_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_67_0)
    MakeCustomInvokeMethodList("MCMathEvalNaturalLogNumber", Evaluate_Type,   MethodListArgs_67_0, MethodList_Nil -> MethodList_67_0)
    MakeCustomInvokeList("BaseELogOperator", "com.livecode.math", MethodList_67_0, List_Nil -> List_68_1)
    DefineCustomInvokeList(68, List_68_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_68_0)
    MakeCustomInvokeMethodList("MCMathEvalBase10LogNumber", Evaluate_Type,   MethodListArgs_68_0, MethodList_Nil -> MethodList_68_0)
    MakeCustomInvokeList("Base10LogOperator", "com.livecode.math", MethodList_68_0, List_Nil -> List_69_1)
    DefineCustomInvokeList(69, List_69_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_69_0)
    MakeCustomInvokeMethodList("MCMathEvalAtan2Number", Evaluate_Type,   MethodListArgs_69_0, MethodList_Nil -> MethodList_69_0)
    MakeCustomInvokeList("BinaryArctanOperator", "com.livecode.math", MethodList_69_0, List_Nil -> List_70_1)
    DefineCustomInvokeList(70, List_70_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_70_0)
    MakeCustomInvokeMethodList("MCMathEvalAtanNumber", Evaluate_Type,   MethodListArgs_70_0, MethodList_Nil -> MethodList_70_0)
    MakeCustomInvokeList("ArctanOperator", "com.livecode.math", MethodList_70_0, List_Nil -> List_71_1)
    DefineCustomInvokeList(71, List_71_1)
    InitializeCustomInvokeLists_70

'action' InitializeCustomInvokeLists_70
  'rule' InitializeCustomInvokeLists_70
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_71_0)
    MakeCustomInvokeMethodList("MCMathEvalAcosNumber", Evaluate_Type,   MethodListArgs_71_0, MethodList_Nil -> MethodList_71_0)
    MakeCustomInvokeList("ArccosOperator", "com.livecode.math", MethodList_71_0, List_Nil -> List_72_1)
    DefineCustomInvokeList(72, List_72_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_72_0)
    MakeCustomInvokeMethodList("MCMathEvalAsinNumber", Evaluate_Type,   MethodListArgs_72_0, MethodList_Nil -> MethodList_72_0)
    MakeCustomInvokeList("ArcsinOperator", "com.livecode.math", MethodList_72_0, List_Nil -> List_73_1)
    DefineCustomInvokeList(73, List_73_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_73_0)
    MakeCustomInvokeMethodList("MCMathEvalTanNumber", Evaluate_Type,   MethodListArgs_73_0, MethodList_Nil -> MethodList_73_0)
    MakeCustomInvokeList("TanOperator", "com.livecode.math", MethodList_73_0, List_Nil -> List_74_1)
    DefineCustomInvokeList(74, List_74_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_74_0)
    MakeCustomInvokeMethodList("MCMathEvalCosNumber", Evaluate_Type,   MethodListArgs_74_0, MethodList_Nil -> MethodList_74_0)
    MakeCustomInvokeList("CosOperator", "com.livecode.math", MethodList_74_0, List_Nil -> List_75_1)
    DefineCustomInvokeList(75, List_75_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_75_0)
    MakeCustomInvokeMethodList("MCMathEvalSinNumber", Evaluate_Type,   MethodListArgs_75_0, MethodList_Nil -> MethodList_75_0)
    MakeCustomInvokeList("SinOperator", "com.livecode.math", MethodList_75_0, List_Nil -> List_76_1)
    DefineCustomInvokeList(76, List_76_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_76_0)
    MakeCustomInvokeMethodList("MCMathEvalNumberToPowerOfNumber", Evaluate_Type,   MethodListArgs_76_0, MethodList_Nil -> MethodList_76_0)
    MakeCustomInvokeList("PowOperator", "com.livecode.math", MethodList_76_0, List_Nil -> List_77_1)
    DefineCustomInvokeList(77, List_77_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_77_0)
    MakeCustomInvokeMethodList("MCLogicExecParseStringAsBool", Execute_Type,   MethodListArgs_77_0, MethodList_Nil -> MethodList_77_0)
    MakeCustomInvokeList("ParseStringAsBoolean", "com.livecode.logic", MethodList_77_0, List_Nil -> List_78_1)
    DefineCustomInvokeList(78, List_78_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_78_0)
    MakeCustomInvokeMethodList("MCLogicEvalStringParsedAsBool", Evaluate_Type,   MethodListArgs_78_0, MethodList_Nil -> MethodList_78_0)
    MakeCustomInvokeList("StringParsedAsBoolean", "com.livecode.logic", MethodList_78_0, List_Nil -> List_79_1)
    DefineCustomInvokeList(79, List_79_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_79_0)
    MakeCustomInvokeMethodList("MCLogicEvalNot", Evaluate_Type,   MethodListArgs_79_0, MethodList_Nil -> MethodList_79_0)
    MakeCustomInvokeList("LogicNot", "com.livecode.logic", MethodList_79_0, List_Nil -> List_80_1)
    DefineCustomInvokeList(80, List_80_1)
    MakeCustomInvokeMethodList("MCListEvalEmpty", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_80_0)
    MakeCustomInvokeList("EmptyList", "com.livecode.list", MethodList_80_0, List_Nil -> List_81_1)
    DefineCustomInvokeList(81, List_81_1)
    InitializeCustomInvokeLists_80

'action' InitializeCustomInvokeLists_80
  'rule' InitializeCustomInvokeLists_80
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, InOut_Mode, 2 -> MethodListArgs_81_0)
    MakeCustomInvokeMethodList("MCListSpliceAfterElementOf", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(InOut_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_81_0)
    MakeCustomInvokeList("SpliceAfterElementOfList", "com.livecode.list", MethodList_81_0, List_Nil -> List_82_1)
    DefineCustomInvokeList(82, List_82_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, InOut_Mode, 2 -> MethodListArgs_82_0)
    MakeCustomInvokeMethodList("MCListSpliceBeforeElementOf", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(InOut_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_82_0)
    MakeCustomInvokeList("SpliceBeforeElementOfList", "com.livecode.list", MethodList_82_0, List_Nil -> List_83_1)
    DefineCustomInvokeList(83, List_83_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, InOut_Mode, 2 -> MethodListArgs_83_0)
    MakeCustomInvokeMethodList("MCListSpliceIntoElementOf", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(InOut_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_83_0)
    MakeCustomInvokeList("SpliceIntoElementOfList", "com.livecode.list", MethodList_83_0, List_Nil -> List_84_1)
    DefineCustomInvokeList(84, List_84_1)
    MakeCustomInvokeMethodList("MCListSpliceIntoElementRangeOf", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(InOut_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_84_0)
    MakeCustomInvokeList("SpliceIntoRangeOfList", "com.livecode.list", MethodList_84_0, List_Nil -> List_85_1)
    DefineCustomInvokeList(85, List_85_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_85_0)
    MakeCustomInvokeMethodList("MCListExecDeleteLastElementOf", Execute_Type,   MethodListArgs_85_0, MethodList_Nil -> MethodList_85_0)
    MakeCustomInvokeList("DeleteLastElementOf", "com.livecode.list", MethodList_85_0, List_Nil -> List_86_1)
    DefineCustomInvokeList(86, List_86_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_86_0)
    MakeCustomInvokeMethodList("MCListExecDeleteFirstElementOf", Execute_Type,   MethodListArgs_86_0, MethodList_Nil -> MethodList_86_0)
    MakeCustomInvokeList("DeleteFirstElementOf", "com.livecode.list", MethodList_86_0, List_Nil -> List_87_1)
    DefineCustomInvokeList(87, List_87_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, InOut_Mode, 2 -> MethodListArgs_87_0)
    MakeCustomInvokeMethodList("MCListExecDeleteElementRangeOf", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(InOut_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_87_0)
    MakeCustomInvokeList("DeleteRangeElementOf", "com.livecode.list", MethodList_87_0, List_Nil -> List_88_1)
    DefineCustomInvokeList(88, List_88_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_88_0)
    MakeCustomInvokeMethodList("MCListExecDeleteElementOf", Execute_Type,   MethodListArgs_88_0, MethodList_Nil -> MethodList_88_0)
    MakeCustomInvokeList("DeleteSingletonElementOf", "com.livecode.list", MethodList_88_0, List_Nil -> List_89_1)
    DefineCustomInvokeList(89, List_89_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_89_1)
    MakeCustomInvokeMethodList("MCListStoreLastElementOf", Assign_Type,   MethodListArgs_89_1, MethodList_Nil -> MethodList_89_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_89_0)
    MakeCustomInvokeMethodList("MCListFetchLastElementOf", Evaluate_Type,   MethodListArgs_89_0, MethodList_89_1 -> MethodList_89_0)
    MakeCustomInvokeList("LastElementOf", "com.livecode.list", MethodList_89_0, List_Nil -> List_90_1)
    DefineCustomInvokeList(90, List_90_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_90_1)
    MakeCustomInvokeMethodList("MCListStoreFirstElementOf", Assign_Type,   MethodListArgs_90_1, MethodList_Nil -> MethodList_90_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_90_0)
    MakeCustomInvokeMethodList("MCListFetchFirstElementOf", Evaluate_Type,   MethodListArgs_90_0, MethodList_90_1 -> MethodList_90_0)
    MakeCustomInvokeList("FirstElementOf", "com.livecode.list", MethodList_90_0, List_Nil -> List_91_1)
    DefineCustomInvokeList(91, List_91_1)
    InitializeCustomInvokeLists_90

'action' InitializeCustomInvokeLists_90
  'rule' InitializeCustomInvokeLists_90
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, InOut_Mode, 2 -> MethodListArgs_91_1)
    MakeCustomInvokeMethodList("MCListStoreElementRangeOf", Assign_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(InOut_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_91_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_91_0)
    MakeCustomInvokeMethodList("MCListFetchElementRangeOf", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_91_1 -> MethodList_91_0)
    MakeCustomInvokeList("RangeElementsOfList", "com.livecode.list", MethodList_91_0, List_Nil -> List_92_1)
    DefineCustomInvokeList(92, List_92_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_92_1)
    MakeCustomInvokeMethodList("MCListStoreElementOf", Assign_Type,   MethodListArgs_92_1, MethodList_Nil -> MethodList_92_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_92_0)
    MakeCustomInvokeMethodList("MCListFetchElementOf", Evaluate_Type,   MethodListArgs_92_0, MethodList_92_1 -> MethodList_92_0)
    MakeCustomInvokeList("SingletonElementOfList", "com.livecode.list", MethodList_92_0, List_Nil -> List_93_1)
    DefineCustomInvokeList(93, List_93_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_93_0)
    MakeCustomInvokeMethodList("MCListExecPopElement", Execute_Type,   MethodListArgs_93_0, MethodList_Nil -> MethodList_93_0)
    MakeCustomInvokeList("PopList", "com.livecode.list", MethodList_93_0, List_Nil -> List_94_1)
    DefineCustomInvokeList(94, List_94_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, InOut_Mode, 2 -> MethodListArgs_94_0)
    MakeCustomInvokeMethodList("MCListExecPushSingleElementOnto", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(InOut_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_94_0)
    MakeCustomInvokeList("PushOntoList", "com.livecode.list", MethodList_94_0, List_Nil -> List_96_1)
    DefineCustomInvokeList(96, List_96_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_95_0)
    MakeCustomInvokeMethodList("MCListEvalTailOf", Evaluate_Type,   MethodListArgs_95_0, MethodList_Nil -> MethodList_95_0)
    MakeCustomInvokeList("TailOfList", "com.livecode.list", MethodList_95_0, List_Nil -> List_98_1)
    DefineCustomInvokeList(98, List_98_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_96_0)
    MakeCustomInvokeMethodList("MCListEvalHeadOf", Evaluate_Type,   MethodListArgs_96_0, MethodList_Nil -> MethodList_96_0)
    MakeCustomInvokeList("HeadOfList", "com.livecode.list", MethodList_96_0, List_Nil -> List_99_1)
    DefineCustomInvokeList(99, List_99_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_97_0)
    MakeCustomInvokeMethodList("MCFileExecGetDirectoryEntries", Evaluate_Type,   MethodListArgs_97_0, MethodList_Nil -> MethodList_97_0)
    MakeCustomInvokeList("GetDirectoryEntries", "com.livecode.file", MethodList_97_0, List_Nil -> List_100_1)
    DefineCustomInvokeList(100, List_100_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_98_0)
    MakeCustomInvokeMethodList("MCFileExecDeleteDirectory", Execute_Type,   MethodListArgs_98_0, MethodList_Nil -> MethodList_98_0)
    MakeCustomInvokeList("DeleteDirectory", "com.livecode.file", MethodList_98_0, List_Nil -> List_101_1)
    DefineCustomInvokeList(101, List_101_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_99_0)
    MakeCustomInvokeMethodList("MCFileExecCreateDirectory", Execute_Type,   MethodListArgs_99_0, MethodList_Nil -> MethodList_99_0)
    MakeCustomInvokeList("CreateDirectory", "com.livecode.file", MethodList_99_0, List_Nil -> List_102_1)
    DefineCustomInvokeList(102, List_102_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_100_0)
    MakeCustomInvokeMethodList("MCFileExecDeleteFile", Execute_Type,   MethodListArgs_100_0, MethodList_Nil -> MethodList_100_0)
    MakeCustomInvokeList("DeleteFile", "com.livecode.file", MethodList_100_0, List_Nil -> List_103_1)
    DefineCustomInvokeList(103, List_103_1)
    InitializeCustomInvokeLists_100

'action' InitializeCustomInvokeLists_100
  'rule' InitializeCustomInvokeLists_100
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_101_1)
    MakeCustomInvokeMethodList("MCFileExecSetContents", Assign_Type,   MethodListArgs_101_1, MethodList_Nil -> MethodList_101_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_101_0)
    MakeCustomInvokeMethodList("MCFileExecGetContents", Evaluate_Type,   MethodListArgs_101_0, MethodList_101_1 -> MethodList_101_0)
    MakeCustomInvokeList("FileContents", "com.livecode.file", MethodList_101_0, List_Nil -> List_104_1)
    DefineCustomInvokeList(104, List_104_1)
    MakeCustomInvokeMethodList("MCDateExecGetUniversalTime", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_102_0)
    MakeCustomInvokeList("UniversalTime", "com.livecode.date", MethodList_102_0, List_Nil -> List_105_1)
    DefineCustomInvokeList(105, List_105_1)
    MakeCustomInvokeMethodList("MCDateExecGetUniversalDate", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_103_0)
    MakeCustomInvokeList("UniversalDate", "com.livecode.date", MethodList_103_0, List_Nil -> List_106_1)
    DefineCustomInvokeList(106, List_106_1)
    MakeCustomInvokeMethodList("MCDateExecGetLocalDate", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_104_0)
    MakeCustomInvokeList("LocalDate", "com.livecode.date", MethodList_104_0, List_Nil -> List_107_1)
    DefineCustomInvokeList(107, List_107_1)
    MakeCustomInvokeMethodArgs1(Out_Mode, 0 -> MethodListArgs_105_0)
    MakeCustomInvokeMethodList("MCCodeunitRepeatForEachCodeunit", Iterate_Type,   MethodListArgs_105_0, MethodList_Nil -> MethodList_105_0)
    MakeCustomInvokeList("RepeatForEachCodeunit", "com.livecode.codeunit", MethodList_105_0, List_Nil -> List_108_1)
    DefineCustomInvokeList(108, List_108_1)
    MakeCustomInvokeMethodList("MCCodeunitEvalOffsetOfCodeunitsBefore", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_106_0)
    MakeCustomInvokeList("CodeunitOffsetBefore", "com.livecode.codeunit", MethodList_106_0, List_Nil -> List_109_1)
    DefineCustomInvokeList(109, List_109_1)
    MakeCustomInvokeMethodList("MCCodeunitEvalOffsetOfCodeunitsAfter", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_107_0)
    MakeCustomInvokeList("CodeunitOffsetAfter", "com.livecode.codeunit", MethodList_107_0, List_Nil -> List_111_1)
    DefineCustomInvokeList(111, List_111_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_108_0)
    MakeCustomInvokeMethodList("MCCodeunitEvalOffsetOfCodeunits", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_108_0)
    MakeCustomInvokeList("CodeunitOffset", "com.livecode.codeunit", MethodList_108_0, List_Nil -> List_113_1)
    DefineCustomInvokeList(113, List_113_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_109_0)
    MakeCustomInvokeMethodList("MCCodeunitExecDeleteLastCodeunitOf", Execute_Type,   MethodListArgs_109_0, MethodList_Nil -> MethodList_109_0)
    MakeCustomInvokeList("DeleteLastCodeunitOf", "com.livecode.codeunit", MethodList_109_0, List_Nil -> List_115_1)
    DefineCustomInvokeList(115, List_115_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_110_0)
    MakeCustomInvokeMethodList("MCCodeunitExecDeleteFirstCodeunitOf", Execute_Type,   MethodListArgs_110_0, MethodList_Nil -> MethodList_110_0)
    MakeCustomInvokeList("DeleteFirstCodeunitOf", "com.livecode.codeunit", MethodList_110_0, List_Nil -> List_116_1)
    DefineCustomInvokeList(116, List_116_1)
    InitializeCustomInvokeLists_110

'action' InitializeCustomInvokeLists_110
  'rule' InitializeCustomInvokeLists_110
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, InOut_Mode, 2 -> MethodListArgs_111_0)
    MakeCustomInvokeMethodList("MCCodeunitExecDeleteCodeunitRangeOf", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(InOut_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_111_0)
    MakeCustomInvokeList("DeleteRangeCodeunitOf", "com.livecode.codeunit", MethodList_111_0, List_Nil -> List_117_1)
    DefineCustomInvokeList(117, List_117_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_112_0)
    MakeCustomInvokeMethodList("MCCodeunitExecDeleteCodeunitOf", Execute_Type,   MethodListArgs_112_0, MethodList_Nil -> MethodList_112_0)
    MakeCustomInvokeList("DeleteSingletonCodeunitOf", "com.livecode.codeunit", MethodList_112_0, List_Nil -> List_118_1)
    DefineCustomInvokeList(118, List_118_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_113_1)
    MakeCustomInvokeMethodList("MCCodeunitStoreLastCodeunitOf", Assign_Type,   MethodListArgs_113_1, MethodList_Nil -> MethodList_113_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_113_0)
    MakeCustomInvokeMethodList("MCCodeunitFetchLastCodeunitOf", Evaluate_Type,   MethodListArgs_113_0, MethodList_113_1 -> MethodList_113_0)
    MakeCustomInvokeList("LastCodeunitOf", "com.livecode.codeunit", MethodList_113_0, List_Nil -> List_119_1)
    DefineCustomInvokeList(119, List_119_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_114_1)
    MakeCustomInvokeMethodList("MCCodeunitStoreFirstCodeunitOf", Assign_Type,   MethodListArgs_114_1, MethodList_Nil -> MethodList_114_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_114_0)
    MakeCustomInvokeMethodList("MCCodeunitFetchFirstCodeunitOf", Evaluate_Type,   MethodListArgs_114_0, MethodList_114_1 -> MethodList_114_0)
    MakeCustomInvokeList("FirstCodeunitOf", "com.livecode.codeunit", MethodList_114_0, List_Nil -> List_120_1)
    DefineCustomInvokeList(120, List_120_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, InOut_Mode, 2 -> MethodListArgs_115_1)
    MakeCustomInvokeMethodList("MCCodeunitStoreCodeunitRangeOf", Assign_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(InOut_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_115_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_115_0)
    MakeCustomInvokeMethodList("MCCodeunitFetchCodeunitRangeOf", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_115_1 -> MethodList_115_0)
    MakeCustomInvokeList("RangeCodeunitOf", "com.livecode.codeunit", MethodList_115_0, List_Nil -> List_121_1)
    DefineCustomInvokeList(121, List_121_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_116_1)
    MakeCustomInvokeMethodList("MCCodeunitStoreCodeunitOf", Assign_Type,   MethodListArgs_116_1, MethodList_Nil -> MethodList_116_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_116_0)
    MakeCustomInvokeMethodList("MCCodeunitFetchCodeunitOf", Evaluate_Type,   MethodListArgs_116_0, MethodList_116_1 -> MethodList_116_0)
    MakeCustomInvokeList("SingletonCodeunitOf", "com.livecode.codeunit", MethodList_116_0, List_Nil -> List_122_1)
    DefineCustomInvokeList(122, List_122_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_117_0)
    MakeCustomInvokeMethodList("MCCodeunitEvalNumberOfCodeunitsIn", Evaluate_Type,   MethodListArgs_117_0, MethodList_Nil -> MethodList_117_0)
    MakeCustomInvokeList("CountCodeunitsOf", "com.livecode.codeunit", MethodList_117_0, List_Nil -> List_123_1)
    DefineCustomInvokeList(123, List_123_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_118_0)
    MakeCustomInvokeMethodList("MCStringEvalCharWithCode", Evaluate_Type,   MethodListArgs_118_0, MethodList_Nil -> MethodList_118_0)
    MakeCustomInvokeList("CharWithCode", "com.livecode.char", MethodList_118_0, List_Nil -> List_124_1)
    DefineCustomInvokeList(124, List_124_1)
    MakeCustomInvokeMethodArgs1(Out_Mode, 0 -> MethodListArgs_119_0)
    MakeCustomInvokeMethodList("MCCharRepeatForEachChar", Iterate_Type,   MethodListArgs_119_0, MethodList_Nil -> MethodList_119_0)
    MakeCustomInvokeList("RepeatForEachChar", "com.livecode.char", MethodList_119_0, List_Nil -> List_125_1)
    DefineCustomInvokeList(125, List_125_1)
    MakeCustomInvokeMethodList("MCCharEvalNewlineCharacter", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_120_0)
    MakeCustomInvokeList("NewLineCharacter", "com.livecode.char", MethodList_120_0, List_Nil -> List_126_1)
    DefineCustomInvokeList(126, List_126_1)
    InitializeCustomInvokeLists_120

'action' InitializeCustomInvokeLists_120
  'rule' InitializeCustomInvokeLists_120
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_121_0)
    MakeCustomInvokeMethodList("MCListEvalIsAmongTheElementsOf", Evaluate_Type,   MethodListArgs_121_0, MethodList_Nil -> MethodList_121_0)
    MakeCustomInvokeList("ElementIsInList", "com.livecode.list", MethodList_121_0, List_Nil -> List_127_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_122_0)
    MakeCustomInvokeMethodList("MCCharEvalIsAmongTheCharsOf", Evaluate_Type,   MethodListArgs_122_0, MethodList_Nil -> MethodList_122_0)
    MakeCustomInvokeList("CharIsInString", "com.livecode.char", MethodList_122_0, List_127_1 -> List_127_2)
    DefineCustomInvokeList(127, List_127_2)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_123_0)
    MakeCustomInvokeMethodList("MCCharExecDeleteLastCharOf", Execute_Type,   MethodListArgs_123_0, MethodList_Nil -> MethodList_123_0)
    MakeCustomInvokeList("DeleteLastCharOf", "com.livecode.char", MethodList_123_0, List_Nil -> List_128_1)
    DefineCustomInvokeList(128, List_128_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_124_0)
    MakeCustomInvokeMethodList("MCCharExecDeleteFirstCharOf", Execute_Type,   MethodListArgs_124_0, MethodList_Nil -> MethodList_124_0)
    MakeCustomInvokeList("DeleteFirstCharOf", "com.livecode.char", MethodList_124_0, List_Nil -> List_129_1)
    DefineCustomInvokeList(129, List_129_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, InOut_Mode, 2 -> MethodListArgs_125_0)
    MakeCustomInvokeMethodList("MCCharExecDeleteCharRangeOf", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(InOut_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_125_0)
    MakeCustomInvokeList("DeleteRangeCharOf", "com.livecode.char", MethodList_125_0, List_Nil -> List_130_1)
    DefineCustomInvokeList(130, List_130_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_126_0)
    MakeCustomInvokeMethodList("MCCharExecDeleteCharOf", Execute_Type,   MethodListArgs_126_0, MethodList_Nil -> MethodList_126_0)
    MakeCustomInvokeList("DeleteSingletonCharOf", "com.livecode.char", MethodList_126_0, List_Nil -> List_131_1)
    DefineCustomInvokeList(131, List_131_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_127_1)
    MakeCustomInvokeMethodList("MCCharStoreLastCharOf", Assign_Type,   MethodListArgs_127_1, MethodList_Nil -> MethodList_127_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_127_0)
    MakeCustomInvokeMethodList("MCCharFetchLastCharOf", Evaluate_Type,   MethodListArgs_127_0, MethodList_127_1 -> MethodList_127_0)
    MakeCustomInvokeList("LastCharOf", "com.livecode.char", MethodList_127_0, List_Nil -> List_132_1)
    DefineCustomInvokeList(132, List_132_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_128_1)
    MakeCustomInvokeMethodList("MCCharStoreFirstCharOf", Assign_Type,   MethodListArgs_128_1, MethodList_Nil -> MethodList_128_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_128_0)
    MakeCustomInvokeMethodList("MCCharFetchFirstCharOf", Evaluate_Type,   MethodListArgs_128_0, MethodList_128_1 -> MethodList_128_0)
    MakeCustomInvokeList("FirstCharOf", "com.livecode.char", MethodList_128_0, List_Nil -> List_133_1)
    DefineCustomInvokeList(133, List_133_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, InOut_Mode, 2 -> MethodListArgs_129_1)
    MakeCustomInvokeMethodList("MCCharStoreCharRangeOf", Assign_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(InOut_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_129_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_129_0)
    MakeCustomInvokeMethodList("MCCharFetchCharRangeOf", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_129_1 -> MethodList_129_0)
    MakeCustomInvokeList("RangeCharOf", "com.livecode.char", MethodList_129_0, List_Nil -> List_134_1)
    DefineCustomInvokeList(134, List_134_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_130_1)
    MakeCustomInvokeMethodList("MCCharStoreCharOf", Assign_Type,   MethodListArgs_130_1, MethodList_Nil -> MethodList_130_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_130_0)
    MakeCustomInvokeMethodList("MCCharFetchCharOf", Evaluate_Type,   MethodListArgs_130_0, MethodList_130_1 -> MethodList_130_0)
    MakeCustomInvokeList("SingletonCharOf", "com.livecode.char", MethodList_130_0, List_Nil -> List_135_1)
    DefineCustomInvokeList(135, List_135_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_131_0)
    MakeCustomInvokeMethodList("MCCharEvalNumberOfCharsIn", Evaluate_Type,   MethodListArgs_131_0, MethodList_Nil -> MethodList_131_0)
    MakeCustomInvokeList("CountCharsOf", "com.livecode.char", MethodList_131_0, List_Nil -> List_136_1)
    DefineCustomInvokeList(136, List_136_1)
    InitializeCustomInvokeLists_130

'action' InitializeCustomInvokeLists_130
  'rule' InitializeCustomInvokeLists_130
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_132_0)
    MakeCustomInvokeMethodList("MCStringEvalCodeOfChar", Evaluate_Type,   MethodListArgs_132_0, MethodList_Nil -> MethodList_132_0)
    MakeCustomInvokeList("CodeOfChar", "com.livecode.char", MethodList_132_0, List_Nil -> List_137_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_133_0)
    MakeCustomInvokeMethodList("MCByteEvalCodeOfByte", Evaluate_Type,   MethodListArgs_133_0, MethodList_Nil -> MethodList_133_0)
    MakeCustomInvokeList("CodeOfByte", "com.livecode.byte", MethodList_133_0, List_137_1 -> List_137_2)
    DefineCustomInvokeList(137, List_137_2)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_134_0)
    MakeCustomInvokeMethodList("MCByteEvalByteWithCode", Evaluate_Type,   MethodListArgs_134_0, MethodList_Nil -> MethodList_134_0)
    MakeCustomInvokeList("ByteWithCode", "com.livecode.byte", MethodList_134_0, List_Nil -> List_138_1)
    DefineCustomInvokeList(138, List_138_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_135_0)
    MakeCustomInvokeMethodList("MCListExecReverseElementsOf", Execute_Type,   MethodListArgs_135_0, MethodList_Nil -> MethodList_135_0)
    MakeCustomInvokeList("ReverseElementsOfList", "com.livecode.list", MethodList_135_0, List_Nil -> List_139_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_136_0)
    MakeCustomInvokeMethodList("MCStringExecReverseCharsOf", Execute_Type,   MethodListArgs_136_0, MethodList_Nil -> MethodList_136_0)
    MakeCustomInvokeList("ReverseCharsOf", "com.livecode.char", MethodList_136_0, List_139_1 -> List_139_2)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_137_0)
    MakeCustomInvokeMethodList("MCDataExecReverseBytesOf", Execute_Type,   MethodListArgs_137_0, MethodList_Nil -> MethodList_137_0)
    MakeCustomInvokeList("ReverseBytesOf", "com.livecode.byte", MethodList_137_0, List_139_2 -> List_139_3)
    DefineCustomInvokeList(139, List_139_3)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_138_0)
    MakeCustomInvokeMethodList("MCDataExecRandomBytes", Evaluate_Type,   MethodListArgs_138_0, MethodList_Nil -> MethodList_138_0)
    MakeCustomInvokeList("RandomBytes", "com.livecode.byte", MethodList_138_0, List_Nil -> List_140_1)
    DefineCustomInvokeList(140, List_140_1)
    MakeCustomInvokeMethodArgs1(Out_Mode, 0 -> MethodListArgs_139_0)
    MakeCustomInvokeMethodList("MCByteRepeatForEachByte", Iterate_Type,   MethodListArgs_139_0, MethodList_Nil -> MethodList_139_0)
    MakeCustomInvokeList("RepeatForEachByte", "com.livecode.byte", MethodList_139_0, List_Nil -> List_141_1)
    DefineCustomInvokeList(141, List_141_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_140_0)
    MakeCustomInvokeMethodList("MCByteExecDeleteLastByteOf", Execute_Type,   MethodListArgs_140_0, MethodList_Nil -> MethodList_140_0)
    MakeCustomInvokeList("DeleteLastByteOf", "com.livecode.byte", MethodList_140_0, List_Nil -> List_142_1)
    DefineCustomInvokeList(142, List_142_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_141_0)
    MakeCustomInvokeMethodList("MCByteExecDeleteFirstByteOf", Execute_Type,   MethodListArgs_141_0, MethodList_Nil -> MethodList_141_0)
    MakeCustomInvokeList("DeleteFirstByteOf", "com.livecode.byte", MethodList_141_0, List_Nil -> List_143_1)
    DefineCustomInvokeList(143, List_143_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, InOut_Mode, 2 -> MethodListArgs_142_0)
    MakeCustomInvokeMethodList("MCByteExecDeleteByteRangeOf", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(InOut_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_142_0)
    MakeCustomInvokeList("DeleteRangeByteOf", "com.livecode.byte", MethodList_142_0, List_Nil -> List_144_1)
    DefineCustomInvokeList(144, List_144_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_143_0)
    MakeCustomInvokeMethodList("MCByteExecDeleteByteOf", Execute_Type,   MethodListArgs_143_0, MethodList_Nil -> MethodList_143_0)
    MakeCustomInvokeList("DeleteSingletonByteOf", "com.livecode.byte", MethodList_143_0, List_Nil -> List_145_1)
    DefineCustomInvokeList(145, List_145_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_144_1)
    MakeCustomInvokeMethodList("MCByteStoreLastByteOf", Assign_Type,   MethodListArgs_144_1, MethodList_Nil -> MethodList_144_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_144_0)
    MakeCustomInvokeMethodList("MCByteFetchLastByteOf", Evaluate_Type,   MethodListArgs_144_0, MethodList_144_1 -> MethodList_144_0)
    MakeCustomInvokeList("LastByteOf", "com.livecode.byte", MethodList_144_0, List_Nil -> List_146_1)
    DefineCustomInvokeList(146, List_146_1)
    InitializeCustomInvokeLists_140

'action' InitializeCustomInvokeLists_140
  'rule' InitializeCustomInvokeLists_140
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_145_1)
    MakeCustomInvokeMethodList("MCByteStoreFirstByteOf", Assign_Type,   MethodListArgs_145_1, MethodList_Nil -> MethodList_145_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_145_0)
    MakeCustomInvokeMethodList("MCByteFetchFirstByteOf", Evaluate_Type,   MethodListArgs_145_0, MethodList_145_1 -> MethodList_145_0)
    MakeCustomInvokeList("FirstByteOf", "com.livecode.byte", MethodList_145_0, List_Nil -> List_147_1)
    DefineCustomInvokeList(147, List_147_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, InOut_Mode, 2 -> MethodListArgs_146_1)
    MakeCustomInvokeMethodList("MCByteStoreByteRangeOf", Assign_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(InOut_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_146_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_146_0)
    MakeCustomInvokeMethodList("MCByteFetchByteRangeOf", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_146_1 -> MethodList_146_0)
    MakeCustomInvokeList("RangeByteOf", "com.livecode.byte", MethodList_146_0, List_Nil -> List_148_1)
    DefineCustomInvokeList(148, List_148_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_147_1)
    MakeCustomInvokeMethodList("MCByteStoreByteOf", Assign_Type,   MethodListArgs_147_1, MethodList_Nil -> MethodList_147_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_147_0)
    MakeCustomInvokeMethodList("MCByteFetchByteOf", Evaluate_Type,   MethodListArgs_147_0, MethodList_147_1 -> MethodList_147_0)
    MakeCustomInvokeList("SingletonByteOf", "com.livecode.byte", MethodList_147_0, List_Nil -> List_149_1)
    DefineCustomInvokeList(149, List_149_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_148_0)
    MakeCustomInvokeMethodList("MCListEvalEndsWith", Evaluate_Type,   MethodListArgs_148_0, MethodList_Nil -> MethodList_148_0)
    MakeCustomInvokeList("ListEndsWithList", "com.livecode.list", MethodList_148_0, List_Nil -> List_150_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_149_0)
    MakeCustomInvokeMethodList("MCCharEvalEndsWith", Evaluate_Type,   MethodListArgs_149_0, MethodList_Nil -> MethodList_149_0)
    MakeCustomInvokeList("StringEndsWithString", "com.livecode.char", MethodList_149_0, List_150_1 -> List_150_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_150_0)
    MakeCustomInvokeMethodList("MCByteEvalEndsWithBytes", Evaluate_Type,   MethodListArgs_150_0, MethodList_Nil -> MethodList_150_0)
    MakeCustomInvokeList("EndsWithBytes", "com.livecode.byte", MethodList_150_0, List_150_2 -> List_150_3)
    DefineCustomInvokeList(150, List_150_3)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_151_0)
    MakeCustomInvokeMethodList("MCListEvalBeginsWith", Evaluate_Type,   MethodListArgs_151_0, MethodList_Nil -> MethodList_151_0)
    MakeCustomInvokeList("ListBeginsWithList", "com.livecode.list", MethodList_151_0, List_Nil -> List_151_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_152_0)
    MakeCustomInvokeMethodList("MCCharEvalBeginsWith", Evaluate_Type,   MethodListArgs_152_0, MethodList_Nil -> MethodList_152_0)
    MakeCustomInvokeList("StringBeginsWithString", "com.livecode.char", MethodList_152_0, List_151_1 -> List_151_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_153_0)
    MakeCustomInvokeMethodList("MCByteEvalBeginsWithBytes", Evaluate_Type,   MethodListArgs_153_0, MethodList_Nil -> MethodList_153_0)
    MakeCustomInvokeList("BeginsWithBytes", "com.livecode.byte", MethodList_153_0, List_151_2 -> List_151_3)
    DefineCustomInvokeList(151, List_151_3)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_154_0)
    MakeCustomInvokeMethodList("MCListEvalContainsElements", Evaluate_Type,   MethodListArgs_154_0, MethodList_Nil -> MethodList_154_0)
    MakeCustomInvokeList("ListContainsElements", "com.livecode.list", MethodList_154_0, List_Nil -> List_152_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_155_0)
    MakeCustomInvokeMethodList("MCCharEvalContains", Evaluate_Type,   MethodListArgs_155_0, MethodList_Nil -> MethodList_155_0)
    MakeCustomInvokeList("ContainsChars", "com.livecode.char", MethodList_155_0, List_152_1 -> List_152_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_156_0)
    MakeCustomInvokeMethodList("MCByteEvalContainsBytes", Evaluate_Type,   MethodListArgs_156_0, MethodList_Nil -> MethodList_156_0)
    MakeCustomInvokeList("ContainsBytes", "com.livecode.byte", MethodList_156_0, List_152_2 -> List_152_3)
    DefineCustomInvokeList(152, List_152_3)
    MakeCustomInvokeMethodList("MCListEvalIndexOfElementBefore", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_157_0)
    MakeCustomInvokeList("ListIndexBefore", "com.livecode.list", MethodList_157_0, List_Nil -> List_153_1)
    MakeCustomInvokeMethodList("MCCharEvalOffsetOfCharsBefore", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_158_0)
    MakeCustomInvokeList("CharIndexBefore", "com.livecode.char", MethodList_158_0, List_153_1 -> List_153_2)
    MakeCustomInvokeMethodList("MCByteEvalOffsetOfBytesBefore", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_159_0)
    MakeCustomInvokeList("ByteIndexBefore", "com.livecode.byte", MethodList_159_0, List_153_2 -> List_153_3)
    DefineCustomInvokeList(153, List_153_3)
    MakeCustomInvokeMethodList("MCListEvalOffsetOfListBefore", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_160_0)
    MakeCustomInvokeList("ListOffsetBefore", "com.livecode.list", MethodList_160_0, List_Nil -> List_155_1)
    MakeCustomInvokeMethodList("MCCharEvalOffsetOfCharsBefore", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_161_0)
    MakeCustomInvokeList("CharOffsetBefore", "com.livecode.char", MethodList_161_0, List_155_1 -> List_155_2)
    MakeCustomInvokeMethodList("MCByteEvalOffsetOfBytesBefore", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_162_0)
    MakeCustomInvokeList("ByteOffsetBefore", "com.livecode.byte", MethodList_162_0, List_155_2 -> List_155_3)
    DefineCustomInvokeList(155, List_155_3)
    MakeCustomInvokeMethodList("MCListEvalIndexOfElementAfter", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_163_0)
    MakeCustomInvokeList("ListIndexAfter", "com.livecode.list", MethodList_163_0, List_Nil -> List_157_1)
    MakeCustomInvokeMethodList("MCCharEvalOffsetOfCharsAfter", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_164_0)
    MakeCustomInvokeList("CharIndexAfter", "com.livecode.char", MethodList_164_0, List_157_1 -> List_157_2)
    MakeCustomInvokeMethodList("MCByteEvalOffsetOfBytesAfter", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_165_0)
    MakeCustomInvokeList("ByteIndexAfter", "com.livecode.byte", MethodList_165_0, List_157_2 -> List_157_3)
    DefineCustomInvokeList(157, List_157_3)
    MakeCustomInvokeMethodList("MCListEvalOffsetOfListAfter", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_166_0)
    MakeCustomInvokeList("ListOffsetAfter", "com.livecode.list", MethodList_166_0, List_Nil -> List_159_1)
    MakeCustomInvokeMethodList("MCCharEvalOffsetOfCharsAfter", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_167_0)
    MakeCustomInvokeList("CharOffsetAfter", "com.livecode.char", MethodList_167_0, List_159_1 -> List_159_2)
    MakeCustomInvokeMethodList("MCByteEvalOffsetOfBytesAfter", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_168_0)
    MakeCustomInvokeList("ByteOffsetAfter", "com.livecode.byte", MethodList_168_0, List_159_2 -> List_159_3)
    DefineCustomInvokeList(159, List_159_3)
    InitializeCustomInvokeLists_150

'action' InitializeCustomInvokeLists_150
  'rule' InitializeCustomInvokeLists_150
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_169_0)
    MakeCustomInvokeMethodList("MCListEvalIndexOfElement", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_169_0)
    MakeCustomInvokeList("ListIndex", "com.livecode.list", MethodList_169_0, List_Nil -> List_161_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_170_0)
    MakeCustomInvokeMethodList("MCCharEvalOffsetOfChars", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_170_0)
    MakeCustomInvokeList("CharIndex", "com.livecode.char", MethodList_170_0, List_161_1 -> List_161_2)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_171_0)
    MakeCustomInvokeMethodList("MCByteEvalOffsetOfBytes", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_171_0)
    MakeCustomInvokeList("ByteIndex", "com.livecode.byte", MethodList_171_0, List_161_2 -> List_161_3)
    DefineCustomInvokeList(161, List_161_3)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_172_0)
    MakeCustomInvokeMethodList("MCListEvalOffsetOfList", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_172_0)
    MakeCustomInvokeList("ListOffset", "com.livecode.list", MethodList_172_0, List_Nil -> List_163_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_173_0)
    MakeCustomInvokeMethodList("MCCharEvalOffsetOfChars", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_173_0)
    MakeCustomInvokeList("CharOffset", "com.livecode.char", MethodList_173_0, List_163_1 -> List_163_2)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_174_0)
    MakeCustomInvokeMethodList("MCByteEvalOffsetOfBytes", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_174_0)
    MakeCustomInvokeList("ByteOffset", "com.livecode.byte", MethodList_174_0, List_163_2 -> List_163_3)
    DefineCustomInvokeList(163, List_163_3)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_175_0)
    MakeCustomInvokeMethodList("MCByteEvalNumberOfBytesIn", Evaluate_Type,   MethodListArgs_175_0, MethodList_Nil -> MethodList_175_0)
    MakeCustomInvokeList("CountBytesOf", "com.livecode.byte", MethodList_175_0, List_Nil -> List_165_1)
    DefineCustomInvokeList(165, List_165_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_176_0)
    MakeCustomInvokeMethodList("MCBitwiseEvalBitwiseShiftRight", Evaluate_Type,   MethodListArgs_176_0, MethodList_Nil -> MethodList_176_0)
    MakeCustomInvokeList("BitwiseShiftRight", "com.livecode.bitwise", MethodList_176_0, List_Nil -> List_166_1)
    DefineCustomInvokeList(166, List_166_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_177_0)
    MakeCustomInvokeMethodList("MCBitwiseEvalBitwiseShiftLeft", Evaluate_Type,   MethodListArgs_177_0, MethodList_Nil -> MethodList_177_0)
    MakeCustomInvokeList("BitwiseShiftLeft", "com.livecode.bitwise", MethodList_177_0, List_Nil -> List_167_1)
    DefineCustomInvokeList(167, List_167_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_178_0)
    MakeCustomInvokeMethodList("MCBitwiseEvalBitwiseNot", Evaluate_Type,   MethodListArgs_178_0, MethodList_Nil -> MethodList_178_0)
    MakeCustomInvokeList("BitwiseNot", "com.livecode.bitwise", MethodList_178_0, List_Nil -> List_168_1)
    DefineCustomInvokeList(168, List_168_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_179_0)
    MakeCustomInvokeMethodList("MCBitwiseEvalBitwiseXor", Evaluate_Type,   MethodListArgs_179_0, MethodList_Nil -> MethodList_179_0)
    MakeCustomInvokeList("BitwiseXor", "com.livecode.bitwise", MethodList_179_0, List_Nil -> List_169_1)
    DefineCustomInvokeList(169, List_169_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_180_0)
    MakeCustomInvokeMethodList("MCBitwiseEvalBitwiseOr", Evaluate_Type,   MethodListArgs_180_0, MethodList_Nil -> MethodList_180_0)
    MakeCustomInvokeList("BitwiseOr", "com.livecode.bitwise", MethodList_180_0, List_Nil -> List_170_1)
    DefineCustomInvokeList(170, List_170_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_181_0)
    MakeCustomInvokeMethodList("MCBitwiseEvalBitwiseAnd", Evaluate_Type,   MethodListArgs_181_0, MethodList_Nil -> MethodList_181_0)
    MakeCustomInvokeList("BitwiseAnd", "com.livecode.bitwise", MethodList_181_0, List_Nil -> List_171_1)
    DefineCustomInvokeList(171, List_171_1)
    MakeCustomInvokeMethodList("MCDataEvalEmpty", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_182_0)
    MakeCustomInvokeList("EmptyData", "com.livecode.binary", MethodList_182_0, List_Nil -> List_172_1)
    DefineCustomInvokeList(172, List_172_1)
    InitializeCustomInvokeLists_160

'action' InitializeCustomInvokeLists_160
  'rule' InitializeCustomInvokeLists_160
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_183_0)
    MakeCustomInvokeMethodList("MCStringEvalConcatenate", Evaluate_Type,   MethodListArgs_183_0, MethodList_Nil -> MethodList_183_0)
    MakeCustomInvokeList("ConcatenateStrings", "com.livecode.string", MethodList_183_0, List_Nil -> List_173_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_184_0)
    MakeCustomInvokeMethodList("MCListEvalConcatenate", Evaluate_Type,   MethodListArgs_184_0, MethodList_Nil -> MethodList_184_0)
    MakeCustomInvokeList("ConcatenateLists", "com.livecode.list", MethodList_184_0, List_173_1 -> List_173_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_185_0)
    MakeCustomInvokeMethodList("MCBinaryEvalConcatenateBytes", Evaluate_Type,   MethodListArgs_185_0, MethodList_Nil -> MethodList_185_0)
    MakeCustomInvokeList("ConcatenateBytes", "com.livecode.binary", MethodList_185_0, List_173_2 -> List_173_3)
    DefineCustomInvokeList(173, List_173_3)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_186_0)
    MakeCustomInvokeMethodList("MCStringExecPutStringAfter", Execute_Type,   MethodListArgs_186_0, MethodList_Nil -> MethodList_186_0)
    MakeCustomInvokeList("PutStringAfter", "com.livecode.string", MethodList_186_0, List_Nil -> List_174_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_187_0)
    MakeCustomInvokeMethodList("MCBinaryExecPutBytesAfter", Execute_Type,   MethodListArgs_187_0, MethodList_Nil -> MethodList_187_0)
    MakeCustomInvokeList("PutBytesAfter", "com.livecode.binary", MethodList_187_0, List_174_1 -> List_174_2)
    DefineCustomInvokeList(174, List_174_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_188_0)
    MakeCustomInvokeMethodList("MCStringExecPutStringBefore", Execute_Type,   MethodListArgs_188_0, MethodList_Nil -> MethodList_188_0)
    MakeCustomInvokeList("PutStringBefore", "com.livecode.string", MethodList_188_0, List_Nil -> List_175_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_189_0)
    MakeCustomInvokeMethodList("MCBinaryExecPutBytesBefore", Execute_Type,   MethodListArgs_189_0, MethodList_Nil -> MethodList_189_0)
    MakeCustomInvokeList("PutBytesBefore", "com.livecode.binary", MethodList_189_0, List_175_1 -> List_175_2)
    DefineCustomInvokeList(175, List_175_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_190_0)
    MakeCustomInvokeMethodList("MCAssertExpectPreconditionWithReason", Execute_Type,   MethodListArgs_190_0, MethodList_Nil -> MethodList_190_0)
    MakeCustomInvokeList("ExpectPreconditionWithReason", "com.livecode.assert", MethodList_190_0, List_Nil -> List_176_1)
    DefineCustomInvokeList(176, List_176_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_191_0)
    MakeCustomInvokeMethodList("MCAssertExpectPrecondition", Execute_Type,   MethodListArgs_191_0, MethodList_Nil -> MethodList_191_0)
    MakeCustomInvokeList("ExpectPrecondition", "com.livecode.assert", MethodList_191_0, List_Nil -> List_178_1)
    DefineCustomInvokeList(178, List_178_1)
    MakeCustomInvokeMethodArgs1(Out_Mode, 0 -> MethodListArgs_192_0)
    MakeCustomInvokeMethodList("MCArrayRepeatForEachKey", Iterate_Type,   MethodListArgs_192_0, MethodList_Nil -> MethodList_192_0)
    MakeCustomInvokeList("RepeatForEachKey", "com.livecode.array", MethodList_192_0, List_Nil -> List_180_1)
    DefineCustomInvokeList(180, List_180_1)
    MakeCustomInvokeMethodArgs1(Out_Mode, 0 -> MethodListArgs_193_0)
    MakeCustomInvokeMethodList("MCListRepeatForEachElement", Iterate_Type,   MethodListArgs_193_0, MethodList_Nil -> MethodList_193_0)
    MakeCustomInvokeList("RepeatForEachElementInList", "com.livecode.list", MethodList_193_0, List_Nil -> List_181_1)
    MakeCustomInvokeMethodArgs1(Out_Mode, 0 -> MethodListArgs_194_0)
    MakeCustomInvokeMethodList("MCArrayRepeatForEachElement", Iterate_Type,   MethodListArgs_194_0, MethodList_Nil -> MethodList_194_0)
    MakeCustomInvokeList("RepeatForEachElementInArray", "com.livecode.array", MethodList_194_0, List_181_1 -> List_181_2)
    DefineCustomInvokeList(181, List_181_2)
    MakeCustomInvokeMethodList("MCArrayEvalEmpty", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_195_0)
    MakeCustomInvokeList("EmptyArray", "com.livecode.array", MethodList_195_0, List_Nil -> List_182_1)
    DefineCustomInvokeList(182, List_182_1)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_196_0)
    MakeCustomInvokeMethodList("MCArrayDeleteElementOfCaseless", Execute_Type,   MethodListArgs_196_0, MethodList_Nil -> MethodList_196_0)
    MakeCustomInvokeList("DeleteElementOfArray", "com.livecode.array", MethodList_196_0, List_Nil -> List_183_1)
    DefineCustomInvokeList(183, List_183_1)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_197_1)
    MakeCustomInvokeMethodList("MCListStoreIndexOf", Assign_Type,   MethodListArgs_197_1, MethodList_Nil -> MethodList_197_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_197_0)
    MakeCustomInvokeMethodList("MCListFetchIndexOf", Evaluate_Type,   MethodListArgs_197_0, MethodList_197_1 -> MethodList_197_0)
    MakeCustomInvokeList("IndexedElementOfList", "com.livecode.list", MethodList_197_0, List_Nil -> List_184_1)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_198_1)
    MakeCustomInvokeMethodList("MCArrayStoreElementOfCaseless", Assign_Type,   MethodListArgs_198_1, MethodList_Nil -> MethodList_198_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_198_0)
    MakeCustomInvokeMethodList("MCArrayFetchElementOfCaseless", Evaluate_Type,   MethodListArgs_198_0, MethodList_198_1 -> MethodList_198_0)
    MakeCustomInvokeList("SingletonElementOfArray", "com.livecode.array", MethodList_198_0, List_184_1 -> List_184_2)
    DefineCustomInvokeList(184, List_184_2)
    InitializeCustomInvokeLists_170

'action' InitializeCustomInvokeLists_170
  'rule' InitializeCustomInvokeLists_170
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_199_0)
    MakeCustomInvokeMethodList("MCArrayEvalIsAmongTheElementsOf", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_199_0)
    MakeCustomInvokeList("AmongElementsOfArray", "com.livecode.array", MethodList_199_0, List_Nil -> List_185_1)
    DefineCustomInvokeList(185, List_185_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_200_0)
    MakeCustomInvokeMethodList("MCArrayEvalIsAmongTheKeysOfCaseless", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_200_0)
    MakeCustomInvokeList("AmongKeysOfArray", "com.livecode.array", MethodList_200_0, List_Nil -> List_187_1)
    DefineCustomInvokeList(187, List_187_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_201_0)
    MakeCustomInvokeMethodList("MCListEvalNumberOfElementsIn", Evaluate_Type,   MethodListArgs_201_0, MethodList_Nil -> MethodList_201_0)
    MakeCustomInvokeList("CountElementsOfList", "com.livecode.list", MethodList_201_0, List_Nil -> List_189_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_202_0)
    MakeCustomInvokeMethodList("MCArrayEvalNumberOfElementsIn", Evaluate_Type,   MethodListArgs_202_0, MethodList_Nil -> MethodList_202_0)
    MakeCustomInvokeList("CountElementsOfArray", "com.livecode.array", MethodList_202_0, List_189_1 -> List_189_2)
    DefineCustomInvokeList(189, List_189_2)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_203_0)
    MakeCustomInvokeMethodList("MCArrayEvalElementsOf", Evaluate_Type,   MethodListArgs_203_0, MethodList_Nil -> MethodList_203_0)
    MakeCustomInvokeList("ElementsOfArray", "com.livecode.array", MethodList_203_0, List_Nil -> List_190_1)
    DefineCustomInvokeList(190, List_190_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_204_0)
    MakeCustomInvokeMethodList("MCArrayEvalKeysOf", Evaluate_Type,   MethodListArgs_204_0, MethodList_Nil -> MethodList_204_0)
    MakeCustomInvokeList("KeysOfArray", "com.livecode.array", MethodList_204_0, List_Nil -> List_191_1)
    DefineCustomInvokeList(191, List_191_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_205_0)
    MakeCustomInvokeMethodList("MCArithmeticExecParseListOfStringAsListOfNumber", Execute_Type,   MethodListArgs_205_0, MethodList_Nil -> MethodList_205_0)
    MakeCustomInvokeList("ParseListOfStringAsListOfNumber", "com.livecode.arithmetic", MethodList_205_0, List_Nil -> List_192_1)
    DefineCustomInvokeList(192, List_192_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_206_0)
    MakeCustomInvokeMethodList("MCArithmeticEvalListOfStringParsedAsListOfNumber", Evaluate_Type,   MethodListArgs_206_0, MethodList_Nil -> MethodList_206_0)
    MakeCustomInvokeList("ListOfStringParsedAsListOfNumber", "com.livecode.arithmetic", MethodList_206_0, List_Nil -> List_193_1)
    DefineCustomInvokeList(193, List_193_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_207_0)
    MakeCustomInvokeMethodList("MCArithmeticExecParseStringAsNumber", Execute_Type,   MethodListArgs_207_0, MethodList_Nil -> MethodList_207_0)
    MakeCustomInvokeList("ParseStringAsNumber", "com.livecode.arithmetic", MethodList_207_0, List_Nil -> List_194_1)
    DefineCustomInvokeList(194, List_194_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_208_0)
    MakeCustomInvokeMethodList("MCArithmeticEvalStringParsedAsNumber", Evaluate_Type,   MethodListArgs_208_0, MethodList_Nil -> MethodList_208_0)
    MakeCustomInvokeList("StringParsedAsNumber", "com.livecode.arithmetic", MethodList_208_0, List_Nil -> List_195_1)
    DefineCustomInvokeList(195, List_195_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_209_0)
    MakeCustomInvokeMethodList("MCLogicExecFormatBoolAsString", Execute_Type,   MethodListArgs_209_0, MethodList_Nil -> MethodList_209_0)
    MakeCustomInvokeList("FormatBooleanAsString", "com.livecode.logic", MethodList_209_0, List_Nil -> List_196_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_210_0)
    MakeCustomInvokeMethodList("MCArithmeticExecFormatNumberAsString", Execute_Type,   MethodListArgs_210_0, MethodList_Nil -> MethodList_210_0)
    MakeCustomInvokeList("FormatNumberAsString", "com.livecode.arithmetic", MethodList_210_0, List_196_1 -> List_196_2)
    DefineCustomInvokeList(196, List_196_2)
    InitializeCustomInvokeLists_180

'action' InitializeCustomInvokeLists_180
  'rule' InitializeCustomInvokeLists_180
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_211_0)
    MakeCustomInvokeMethodList("MCLogicEvalBoolFormattedAsString", Evaluate_Type,   MethodListArgs_211_0, MethodList_Nil -> MethodList_211_0)
    MakeCustomInvokeList("BooleanFormattedAsString", "com.livecode.logic", MethodList_211_0, List_Nil -> List_197_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_212_0)
    MakeCustomInvokeMethodList("MCArithmeticEvalNumberFormattedAsString", Evaluate_Type,   MethodListArgs_212_0, MethodList_Nil -> MethodList_212_0)
    MakeCustomInvokeList("NumberFormattedAsString", "com.livecode.arithmetic", MethodList_212_0, List_197_1 -> List_197_2)
    DefineCustomInvokeList(197, List_197_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_213_2)
    MakeCustomInvokeMethodList("MCNothingEvalIsNothingNotEqualToNothing", Evaluate_Type,   MethodListArgs_213_2, MethodList_Nil -> MethodList_213_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_213_1)
    MakeCustomInvokeMethodList("MCNothingEvalIsNothingNotEqualTo", Evaluate_Type,   MethodListArgs_213_1, MethodList_213_2 -> MethodList_213_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_213_0)
    MakeCustomInvokeMethodList("MCNothingEvalIsNotEqualToNothing", Evaluate_Type,   MethodListArgs_213_0, MethodList_213_1 -> MethodList_213_0)
    MakeCustomInvokeList("NothingIsNotNothing", "com.livecode.type", MethodList_213_0, List_Nil -> List_198_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_214_0)
    MakeCustomInvokeMethodList("MCStringEvalIsNotEqualTo", Evaluate_Type,   MethodListArgs_214_0, MethodList_Nil -> MethodList_214_0)
    MakeCustomInvokeList("StringIsNotString", "com.livecode.string", MethodList_214_0, List_198_1 -> List_198_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_215_0)
    MakeCustomInvokeMethodList("MCLogicEvalIsNotEqualTo", Evaluate_Type,   MethodListArgs_215_0, MethodList_Nil -> MethodList_215_0)
    MakeCustomInvokeList("BooleanIsNotEqualToBoolean", "com.livecode.logic", MethodList_215_0, List_198_2 -> List_198_3)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_216_0)
    MakeCustomInvokeMethodList("MCListEvalIsNotEqualTo", Evaluate_Type,   MethodListArgs_216_0, MethodList_Nil -> MethodList_216_0)
    MakeCustomInvokeList("ListIsNotList", "com.livecode.list", MethodList_216_0, List_198_3 -> List_198_4)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_217_0)
    MakeCustomInvokeMethodList("MCBinaryEvalIsNotEqualTo", Evaluate_Type,   MethodListArgs_217_0, MethodList_Nil -> MethodList_217_0)
    MakeCustomInvokeList("DataIsNotData", "com.livecode.binary", MethodList_217_0, List_198_4 -> List_198_5)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_218_0)
    MakeCustomInvokeMethodList("MCArithmeticEvalNotEqualToNumber", Evaluate_Type,   MethodListArgs_218_0, MethodList_Nil -> MethodList_218_0)
    MakeCustomInvokeList("NumberIsNotNumber", "com.livecode.arithmetic", MethodList_218_0, List_198_5 -> List_198_6)
    DefineCustomInvokeList(198, List_198_6)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_219_2)
    MakeCustomInvokeMethodList("MCNothingEvalIsNothingEqualToNothing", Evaluate_Type,   MethodListArgs_219_2, MethodList_Nil -> MethodList_219_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_219_1)
    MakeCustomInvokeMethodList("MCNothingEvalIsNothingEqualTo", Evaluate_Type,   MethodListArgs_219_1, MethodList_219_2 -> MethodList_219_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_219_0)
    MakeCustomInvokeMethodList("MCNothingEvalIsEqualToNothing", Evaluate_Type,   MethodListArgs_219_0, MethodList_219_1 -> MethodList_219_0)
    MakeCustomInvokeList("NothingIsNothing", "com.livecode.type", MethodList_219_0, List_Nil -> List_199_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_220_0)
    MakeCustomInvokeMethodList("MCStringEvalIsEqualTo", Evaluate_Type,   MethodListArgs_220_0, MethodList_Nil -> MethodList_220_0)
    MakeCustomInvokeList("StringIsString", "com.livecode.string", MethodList_220_0, List_199_1 -> List_199_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_221_0)
    MakeCustomInvokeMethodList("MCLogicEvalIsEqualTo", Evaluate_Type,   MethodListArgs_221_0, MethodList_Nil -> MethodList_221_0)
    MakeCustomInvokeList("BooleanIsEqualToBoolean", "com.livecode.logic", MethodList_221_0, List_199_2 -> List_199_3)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_222_0)
    MakeCustomInvokeMethodList("MCListEvalIsEqualTo", Evaluate_Type,   MethodListArgs_222_0, MethodList_Nil -> MethodList_222_0)
    MakeCustomInvokeList("ListIsList", "com.livecode.list", MethodList_222_0, List_199_3 -> List_199_4)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_223_0)
    MakeCustomInvokeMethodList("MCBinaryEvalIsEqualTo", Evaluate_Type,   MethodListArgs_223_0, MethodList_Nil -> MethodList_223_0)
    MakeCustomInvokeList("DataIsData", "com.livecode.binary", MethodList_223_0, List_199_4 -> List_199_5)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_224_0)
    MakeCustomInvokeMethodList("MCArithmeticEvalEqualToNumber", Evaluate_Type,   MethodListArgs_224_0, MethodList_Nil -> MethodList_224_0)
    MakeCustomInvokeList("NumberIsNumber", "com.livecode.arithmetic", MethodList_224_0, List_199_5 -> List_199_6)
    DefineCustomInvokeList(199, List_199_6)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_225_0)
    MakeCustomInvokeMethodList("MCArithmeticEvalEqualToNumber", Evaluate_Type,   MethodListArgs_225_0, MethodList_Nil -> MethodList_225_0)
    MakeCustomInvokeList("NumberIsEqualToNumber", "com.livecode.arithmetic", MethodList_225_0, List_Nil -> List_200_1)
    DefineCustomInvokeList(200, List_200_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_226_0)
    MakeCustomInvokeMethodList("MCArithmeticEvalNumberIsLessThanOrEqualToNumber", Evaluate_Type,   MethodListArgs_226_0, MethodList_Nil -> MethodList_226_0)
    MakeCustomInvokeList("NumberIsLessThanOrEqualToNumber", "com.livecode.arithmetic", MethodList_226_0, List_Nil -> List_201_1)
    DefineCustomInvokeList(201, List_201_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_227_0)
    MakeCustomInvokeMethodList("MCStringEvalIsLessThan", Evaluate_Type,   MethodListArgs_227_0, MethodList_Nil -> MethodList_227_0)
    MakeCustomInvokeList("StringIsLessThanString", "com.livecode.string", MethodList_227_0, List_Nil -> List_202_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_228_0)
    MakeCustomInvokeMethodList("MCBinaryEvalIsLessThan", Evaluate_Type,   MethodListArgs_228_0, MethodList_Nil -> MethodList_228_0)
    MakeCustomInvokeList("DataIsLessThanData", "com.livecode.binary", MethodList_228_0, List_202_1 -> List_202_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_229_0)
    MakeCustomInvokeMethodList("MCArithmeticEvalNumberIsLessThanNumber", Evaluate_Type,   MethodListArgs_229_0, MethodList_Nil -> MethodList_229_0)
    MakeCustomInvokeList("NumberIsLessThanNumber", "com.livecode.arithmetic", MethodList_229_0, List_202_2 -> List_202_3)
    DefineCustomInvokeList(202, List_202_3)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_230_0)
    MakeCustomInvokeMethodList("MCArithmeticEvalNumberIsGreaterThanOrEqualToNumber", Evaluate_Type,   MethodListArgs_230_0, MethodList_Nil -> MethodList_230_0)
    MakeCustomInvokeList("NumberIsGreaterThanOrEqualToNumber", "com.livecode.arithmetic", MethodList_230_0, List_Nil -> List_203_1)
    DefineCustomInvokeList(203, List_203_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_231_0)
    MakeCustomInvokeMethodList("MCStringEvalIsGreaterThan", Evaluate_Type,   MethodListArgs_231_0, MethodList_Nil -> MethodList_231_0)
    MakeCustomInvokeList("StringIsGreaterThanString", "com.livecode.string", MethodList_231_0, List_Nil -> List_204_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_232_0)
    MakeCustomInvokeMethodList("MCBinaryEvalIsGreaterThan", Evaluate_Type,   MethodListArgs_232_0, MethodList_Nil -> MethodList_232_0)
    MakeCustomInvokeList("DataIsGreaterThanData", "com.livecode.binary", MethodList_232_0, List_204_1 -> List_204_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_233_0)
    MakeCustomInvokeMethodList("MCArithmeticEvalNumberIsGreaterThanNumber", Evaluate_Type,   MethodListArgs_233_0, MethodList_Nil -> MethodList_233_0)
    MakeCustomInvokeList("NumberIsGreaterThanNumber", "com.livecode.arithmetic", MethodList_233_0, List_204_2 -> List_204_3)
    DefineCustomInvokeList(204, List_204_3)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_234_0)
    MakeCustomInvokeMethodList("MCArithmeticEvalNumberWrapNumber", Evaluate_Type,   MethodListArgs_234_0, MethodList_Nil -> MethodList_234_0)
    MakeCustomInvokeList("WrapOperator", "com.livecode.arithmetic", MethodList_234_0, List_Nil -> List_205_1)
    DefineCustomInvokeList(205, List_205_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_235_0)
    MakeCustomInvokeMethodList("MCArithmeticEvalNumberModNumber", Evaluate_Type,   MethodListArgs_235_0, MethodList_Nil -> MethodList_235_0)
    MakeCustomInvokeList("ModOperator", "com.livecode.arithmetic", MethodList_235_0, List_Nil -> List_206_1)
    DefineCustomInvokeList(206, List_206_1)
    InitializeCustomInvokeLists_190

'action' InitializeCustomInvokeLists_190
  'rule' InitializeCustomInvokeLists_190
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_236_0)
    MakeCustomInvokeMethodList("MCArithmeticEvalNumberOverNumber", Evaluate_Type,   MethodListArgs_236_0, MethodList_Nil -> MethodList_236_0)
    MakeCustomInvokeList("OverOperator", "com.livecode.arithmetic", MethodList_236_0, List_Nil -> List_207_1)
    DefineCustomInvokeList(207, List_207_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_237_0)
    MakeCustomInvokeMethodList("MCArithmeticEvalNumberMinusNumber", Evaluate_Type,   MethodListArgs_237_0, MethodList_Nil -> MethodList_237_0)
    MakeCustomInvokeList("MinusOperator", "com.livecode.arithmetic", MethodList_237_0, List_Nil -> List_208_1)
    DefineCustomInvokeList(208, List_208_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_238_0)
    MakeCustomInvokeMethodList("MCArithmeticEvalNumberPlusNumber", Evaluate_Type,   MethodListArgs_238_0, MethodList_Nil -> MethodList_238_0)
    MakeCustomInvokeList("PlusOperator", "com.livecode.arithmetic", MethodList_238_0, List_Nil -> List_209_1)
    DefineCustomInvokeList(209, List_209_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_239_0)
    MakeCustomInvokeMethodList("MCArithmeticEvalMinusNumber", Evaluate_Type,   MethodListArgs_239_0, MethodList_Nil -> MethodList_239_0)
    MakeCustomInvokeList("MinusUnaryOperator", "com.livecode.arithmetic", MethodList_239_0, List_Nil -> List_210_1)
    DefineCustomInvokeList(210, List_210_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_240_0)
    MakeCustomInvokeMethodList("MCArithmeticEvalPlusNumber", Evaluate_Type,   MethodListArgs_240_0, MethodList_Nil -> MethodList_240_0)
    MakeCustomInvokeList("PlusUnaryOperator", "com.livecode.arithmetic", MethodList_240_0, List_Nil -> List_211_1)
    DefineCustomInvokeList(211, List_211_1)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_241_0)
    MakeCustomInvokeMethodList("MCArithmeticExecDivideNumberByNumber", Execute_Type,   MethodListArgs_241_0, MethodList_Nil -> MethodList_241_0)
    MakeCustomInvokeList("DivideNumberBy", "com.livecode.arithmetic", MethodList_241_0, List_Nil -> List_212_1)
    DefineCustomInvokeList(212, List_212_1)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_242_0)
    MakeCustomInvokeMethodList("MCArithmeticExecMultiplyNumberByNumber", Execute_Type,   MethodListArgs_242_0, MethodList_Nil -> MethodList_242_0)
    MakeCustomInvokeList("MultiplyNumberBy", "com.livecode.arithmetic", MethodList_242_0, List_Nil -> List_213_1)
    DefineCustomInvokeList(213, List_213_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_243_0)
    MakeCustomInvokeMethodList("MCArithmeticExecSubtractNumberFromNumber", Execute_Type,   MethodListArgs_243_0, MethodList_Nil -> MethodList_243_0)
    MakeCustomInvokeList("SubtractNumberFrom", "com.livecode.arithmetic", MethodList_243_0, List_Nil -> List_214_1)
    DefineCustomInvokeList(214, List_214_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_244_0)
    MakeCustomInvokeMethodList("MCLicenseCheckEdition", Evaluate_Type,   MethodListArgs_244_0, MethodList_Nil -> MethodList_244_0)
    MakeCustomInvokeList("LicensedEdition", "com.livecode.commercial.license", MethodList_244_0, List_Nil -> List_215_1)
    DefineCustomInvokeList(215, List_215_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_245_1)
    MakeCustomInvokeMethodList("MCLicenseCheckExtensionFeature", Evaluate_Type,   MethodListArgs_245_1, MethodList_Nil -> MethodList_245_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 1 -> MethodListArgs_245_0)
    MakeCustomInvokeMethodList("MCLicenseCheckExtension", Evaluate_Type,   MethodListArgs_245_0, MethodList_245_1 -> MethodList_245_0)
    MakeCustomInvokeList("LicensedExtension", "com.livecode.commercial.license", MethodList_245_0, List_Nil -> List_216_1)
    DefineCustomInvokeList(216, List_216_1)
    InitializeCustomInvokeLists_200

'action' InitializeCustomInvokeLists_200
  'rule' InitializeCustomInvokeLists_200
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs2(In_Mode, 1, In_Mode, 2 -> MethodListArgs_246_3)
    MakeCustomInvokeMethodList("MCLicenseEnsureExtensionOrEdition", Execute_Type,   MethodListArgs_246_3, MethodList_Nil -> MethodList_246_3)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_246_2)
    MakeCustomInvokeMethodList("MCLicenseEnsureExtensionFeatureOrEdition", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_246_3 -> MethodList_246_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_246_1)
    MakeCustomInvokeMethodList("MCLicenseEnsureExtensionFeature", Execute_Type,   MethodListArgs_246_1, MethodList_246_2 -> MethodList_246_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 1 -> MethodListArgs_246_0)
    MakeCustomInvokeMethodList("MCLicenseEnsureExtension", Execute_Type,   MethodListArgs_246_0, MethodList_246_1 -> MethodList_246_0)
    MakeCustomInvokeList("EnsureLicense", "com.livecode.commercial.license", MethodList_246_0, List_Nil -> List_218_1)
    DefineCustomInvokeList(218, List_218_1)
    MakeCustomInvokeMethodList("MCWidgetSetMyNativeLayer", Assign_Type,  Signature_Nil, MethodList_Nil -> MethodList_247_1)
    MakeCustomInvokeMethodList("MCWidgetGetMyNativeLayer", Evaluate_Type,  Signature_Nil, MethodList_247_1 -> MethodList_247_0)
    MakeCustomInvokeList("MyNativeLayer", "com.livecode.widget", MethodList_247_0, List_Nil -> List_221_1)
    DefineCustomInvokeList(221, List_221_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_248_1)
    MakeCustomInvokeMethodList("MCWidgetSetNativeLayerOfWidget", Assign_Type,   MethodListArgs_248_1, MethodList_Nil -> MethodList_248_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_248_0)
    MakeCustomInvokeMethodList("MCWidgetGetNativeLayerOfWidget", Evaluate_Type,   MethodListArgs_248_0, MethodList_248_1 -> MethodList_248_0)
    MakeCustomInvokeList("NativeLayerOfWidget", "com.livecode.widget", MethodList_248_0, List_Nil -> List_222_1)
    DefineCustomInvokeList(222, List_222_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_249_1)
    MakeCustomInvokeMethodList("MCWidgetSetAnnotationOfWidget", Assign_Type,   MethodListArgs_249_1, MethodList_Nil -> MethodList_249_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_249_0)
    MakeCustomInvokeMethodList("MCWidgetGetAnnotationOfWidget", Evaluate_Type,   MethodListArgs_249_0, MethodList_249_1 -> MethodList_249_0)
    MakeCustomInvokeList("AnnotationOfWidget", "com.livecode.widget", MethodList_249_0, List_Nil -> List_223_1)
    DefineCustomInvokeList(223, List_223_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_250_1)
    MakeCustomInvokeMethodList("MCWidgetSetDisabledOfWidget", Assign_Type,   MethodListArgs_250_1, MethodList_Nil -> MethodList_250_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_250_0)
    MakeCustomInvokeMethodList("MCWidgetGetDisabledOfWidget", Evaluate_Type,   MethodListArgs_250_0, MethodList_250_1 -> MethodList_250_0)
    MakeCustomInvokeList("WidgetDisabledProperty", "com.livecode.widget", MethodList_250_0, List_Nil -> List_224_1)
    DefineCustomInvokeList(224, List_224_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_251_1)
    MakeCustomInvokeMethodList("MCWidgetSetEnabledOfWidget", Assign_Type,   MethodListArgs_251_1, MethodList_Nil -> MethodList_251_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_251_0)
    MakeCustomInvokeMethodList("MCWidgetGetEnabledOfWidget", Evaluate_Type,   MethodListArgs_251_0, MethodList_251_1 -> MethodList_251_0)
    MakeCustomInvokeList("WidgetEnabledProperty", "com.livecode.widget", MethodList_251_0, List_Nil -> List_225_1)
    DefineCustomInvokeList(225, List_225_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_252_1)
    MakeCustomInvokeMethodList("MCWidgetSetLocationOfWidget", Assign_Type,   MethodListArgs_252_1, MethodList_Nil -> MethodList_252_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_252_0)
    MakeCustomInvokeMethodList("MCWidgetGetLocationOfWidget", Evaluate_Type,   MethodListArgs_252_0, MethodList_252_1 -> MethodList_252_0)
    MakeCustomInvokeList("WidgetLocationProperty", "com.livecode.widget", MethodList_252_0, List_Nil -> List_226_1)
    DefineCustomInvokeList(226, List_226_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_253_1)
    MakeCustomInvokeMethodList("MCWidgetSetRectangleOfWidget", Assign_Type,   MethodListArgs_253_1, MethodList_Nil -> MethodList_253_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_253_0)
    MakeCustomInvokeMethodList("MCWidgetGetRectangleOfWidget", Evaluate_Type,   MethodListArgs_253_0, MethodList_253_1 -> MethodList_253_0)
    MakeCustomInvokeList("WidgetRectangleProperty", "com.livecode.widget", MethodList_253_0, List_Nil -> List_227_1)
    DefineCustomInvokeList(227, List_227_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_254_0)
    MakeCustomInvokeMethodList("MCWidgetExecUnplaceWidget", Execute_Type,   MethodListArgs_254_0, MethodList_Nil -> MethodList_254_0)
    MakeCustomInvokeList("UnplaceWidget", "com.livecode.widget", MethodList_254_0, List_Nil -> List_228_1)
    DefineCustomInvokeList(228, List_228_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 3 -> MethodListArgs_255_0)
    MakeCustomInvokeMethodList("MCWidgetExecPlaceWidgetRelative", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 3, Signature_Nil))), MethodList_Nil -> MethodList_255_0)
    MakeCustomInvokeList("PlaceWidgetRelative", "com.livecode.widget", MethodList_255_0, List_Nil -> List_229_1)
    DefineCustomInvokeList(229, List_229_1)
    InitializeCustomInvokeLists_210

'action' InitializeCustomInvokeLists_210
  'rule' InitializeCustomInvokeLists_210
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_256_0)
    MakeCustomInvokeMethodList("MCWidgetExecPlaceWidgetAt", Execute_Type,   MethodListArgs_256_0, MethodList_Nil -> MethodList_256_0)
    MakeCustomInvokeList("PlaceWidgetAt", "com.livecode.widget", MethodList_256_0, List_Nil -> List_231_1)
    DefineCustomInvokeList(231, List_231_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_257_0)
    MakeCustomInvokeMethodList("MCWidgetExecPlaceWidget", Execute_Type,   MethodListArgs_257_0, MethodList_Nil -> MethodList_257_0)
    MakeCustomInvokeList("PlaceWidget", "com.livecode.widget", MethodList_257_0, List_Nil -> List_233_1)
    DefineCustomInvokeList(233, List_233_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_258_0)
    MakeCustomInvokeMethodList("MCWidgetEvalANewWidget", Evaluate_Type,   MethodListArgs_258_0, MethodList_Nil -> MethodList_258_0)
    MakeCustomInvokeList("ANewWidget", "com.livecode.widget", MethodList_258_0, List_Nil -> List_234_1)
    DefineCustomInvokeList(234, List_234_1)
    MakeCustomInvokeMethodList("MCWidgetEvalMyChildren", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_259_0)
    MakeCustomInvokeList("MyChildren", "com.livecode.widget", MethodList_259_0, List_Nil -> List_235_1)
    DefineCustomInvokeList(235, List_235_1)
    MakeCustomInvokeMethodList("MCWidgetEvalThisWidget", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_260_0)
    MakeCustomInvokeList("ThisWidget", "com.livecode.widget", MethodList_260_0, List_Nil -> List_236_1)
    DefineCustomInvokeList(236, List_236_1)
    MakeCustomInvokeMethodList("MCWidgetEvalTheTarget", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_261_0)
    MakeCustomInvokeList("TheTarget", "com.livecode.widget", MethodList_261_0, List_Nil -> List_237_1)
    DefineCustomInvokeList(237, List_237_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_262_1)
    MakeCustomInvokeMethodList("MCWidgetExecClosePopupWithResult", Execute_Type,   MethodListArgs_262_1, MethodList_Nil -> MethodList_262_1)
    MakeCustomInvokeMethodList("MCWidgetExecClosePopup", Execute_Type,  Signature_Nil, MethodList_262_1 -> MethodList_262_0)
    MakeCustomInvokeList("ClosePopupWithResult", "com.livecode.widget", MethodList_262_0, List_Nil -> List_238_1)
    DefineCustomInvokeList(238, List_238_1)
    MakeCustomInvokeMethodList("MCWidgetEvalIsPopup", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_263_0)
    MakeCustomInvokeList("IsPoppedUp", "com.livecode.widget", MethodList_263_0, List_Nil -> List_240_1)
    DefineCustomInvokeList(240, List_240_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_264_1)
    MakeCustomInvokeMethodList("MCWidgetExecPopupAtLocationWithProperties", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_264_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_264_0)
    MakeCustomInvokeMethodList("MCWidgetExecPopupAtLocation", Execute_Type,   MethodListArgs_264_0, MethodList_264_1 -> MethodList_264_0)
    MakeCustomInvokeList("PopupWidget", "com.livecode.widget", MethodList_264_0, List_Nil -> List_241_1)
    DefineCustomInvokeList(241, List_241_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_265_0)
    MakeCustomInvokeMethodList("MCWidgetExecPopupMenuAtLocation", Execute_Type,   MethodListArgs_265_0, MethodList_Nil -> MethodList_265_0)
    MakeCustomInvokeList("PopupMenu", "com.livecode.widget", MethodList_265_0, List_Nil -> List_243_1)
    DefineCustomInvokeList(243, List_243_1)
    InitializeCustomInvokeLists_220

'action' InitializeCustomInvokeLists_220
  'rule' InitializeCustomInvokeLists_220
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_266_0)
    MakeCustomInvokeMethodList("MCWidgetEvalIsPointNotWithinRect", Evaluate_Type,   MethodListArgs_266_0, MethodList_Nil -> MethodList_266_0)
    MakeCustomInvokeList("IsPointNotWithinRect", "com.livecode.widget", MethodList_266_0, List_Nil -> List_244_1)
    DefineCustomInvokeList(244, List_244_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_267_0)
    MakeCustomInvokeMethodList("MCWidgetEvalIsPointWithinRect", Evaluate_Type,   MethodListArgs_267_0, MethodList_Nil -> MethodList_267_0)
    MakeCustomInvokeList("IsPointWithinRect", "com.livecode.widget", MethodList_267_0, List_Nil -> List_245_1)
    DefineCustomInvokeList(245, List_245_1)
    MakeCustomInvokeMethodList("MCWidgetGetTouchIDs", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_268_0)
    MakeCustomInvokeList("TheTouchIDs", "com.livecode.widget", MethodList_268_0, List_Nil -> List_246_1)
    DefineCustomInvokeList(246, List_246_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_269_0)
    MakeCustomInvokeMethodList("MCWidgetGetPositionOfTouch", Evaluate_Type,   MethodListArgs_269_0, MethodList_Nil -> MethodList_269_0)
    MakeCustomInvokeList("TheLocationOfTouch", "com.livecode.widget", MethodList_269_0, List_Nil -> List_247_1)
    DefineCustomInvokeList(247, List_247_1)
    MakeCustomInvokeMethodList("MCWidgetGetNumberOfTouches", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_270_0)
    MakeCustomInvokeList("TheNumberOfTouches", "com.livecode.widget", MethodList_270_0, List_Nil -> List_248_1)
    DefineCustomInvokeList(248, List_248_1)
    MakeCustomInvokeMethodList("MCWidgetGetTouchPosition", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_271_0)
    MakeCustomInvokeList("TheTouchLocation", "com.livecode.widget", MethodList_271_0, List_Nil -> List_249_1)
    DefineCustomInvokeList(249, List_249_1)
    MakeCustomInvokeMethodList("MCWidgetGetTouchId", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_272_0)
    MakeCustomInvokeList("TheTouchId", "com.livecode.widget", MethodList_272_0, List_Nil -> List_250_1)
    DefineCustomInvokeList(250, List_250_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_273_0)
    MakeCustomInvokeMethodList("MCWidgetGetClickCount", Evaluate_Type,   MethodListArgs_273_0, MethodList_Nil -> MethodList_273_0)
    MakeCustomInvokeList("TheClickCount", "com.livecode.widget", MethodList_273_0, List_Nil -> List_251_1)
    DefineCustomInvokeList(251, List_251_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_274_0)
    MakeCustomInvokeMethodList("MCWidgetGetClickButton", Evaluate_Type,   MethodListArgs_274_0, MethodList_Nil -> MethodList_274_0)
    MakeCustomInvokeList("TheClickButton", "com.livecode.widget", MethodList_274_0, List_Nil -> List_253_1)
    DefineCustomInvokeList(253, List_253_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_275_0)
    MakeCustomInvokeMethodList("MCWidgetGetClickPosition", Evaluate_Type,   MethodListArgs_275_0, MethodList_Nil -> MethodList_275_0)
    MakeCustomInvokeList("TheClickLocation", "com.livecode.widget", MethodList_275_0, List_Nil -> List_255_1)
    DefineCustomInvokeList(255, List_255_1)
    InitializeCustomInvokeLists_230

'action' InitializeCustomInvokeLists_230
  'rule' InitializeCustomInvokeLists_230
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_276_0)
    MakeCustomInvokeMethodList("MCWidgetGetMousePosition", Evaluate_Type,   MethodListArgs_276_0, MethodList_Nil -> MethodList_276_0)
    MakeCustomInvokeList("TheMouseLocation", "com.livecode.widget", MethodList_276_0, List_Nil -> List_257_1)
    DefineCustomInvokeList(257, List_257_1)
    MakeCustomInvokeMethodList("MCWidgetGetMyPixelScale", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_277_0)
    MakeCustomInvokeList("MyPixelScale", "com.livecode.widget", MethodList_277_0, List_Nil -> List_259_1)
    DefineCustomInvokeList(259, List_259_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_278_0)
    MakeCustomInvokeMethodList("MCWidgetGetMyPaint", Evaluate_Type,   MethodListArgs_278_0, MethodList_Nil -> MethodList_278_0)
    MakeCustomInvokeList("MyPaint", "com.livecode.widget", MethodList_278_0, List_Nil -> List_260_1)
    DefineCustomInvokeList(260, List_260_1)
    MakeCustomInvokeMethodList("MCWidgetGetMyDisabled", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_279_0)
    MakeCustomInvokeList("MyDisabled", "com.livecode.widget", MethodList_279_0, List_Nil -> List_262_1)
    DefineCustomInvokeList(262, List_262_1)
    MakeCustomInvokeMethodList("MCWidgetGetMyEnabled", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_280_0)
    MakeCustomInvokeList("MyEnabled", "com.livecode.widget", MethodList_280_0, List_Nil -> List_263_1)
    DefineCustomInvokeList(263, List_263_1)
    MakeCustomInvokeMethodList("MCWidgetGetMyFont", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_281_0)
    MakeCustomInvokeList("MyFont", "com.livecode.widget", MethodList_281_0, List_Nil -> List_264_1)
    DefineCustomInvokeList(264, List_264_1)
    MakeCustomInvokeMethodList("MCWidgetGetMyHeight", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_282_0)
    MakeCustomInvokeList("MyHeight", "com.livecode.widget", MethodList_282_0, List_Nil -> List_265_1)
    DefineCustomInvokeList(265, List_265_1)
    MakeCustomInvokeMethodList("MCWidgetGetMyWidth", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_283_0)
    MakeCustomInvokeList("MyWidth", "com.livecode.widget", MethodList_283_0, List_Nil -> List_266_1)
    DefineCustomInvokeList(266, List_266_1)
    MakeCustomInvokeMethodList("MCWidgetGetMyBounds", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_284_0)
    MakeCustomInvokeList("MyBounds", "com.livecode.widget", MethodList_284_0, List_Nil -> List_267_1)
    DefineCustomInvokeList(267, List_267_1)
    MakeCustomInvokeMethodList("MCWidgetGetMyRectangle", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_285_0)
    MakeCustomInvokeList("MyRectangle", "com.livecode.widget", MethodList_285_0, List_Nil -> List_268_1)
    DefineCustomInvokeList(268, List_268_1)
    InitializeCustomInvokeLists_240

'action' InitializeCustomInvokeLists_240
  'rule' InitializeCustomInvokeLists_240
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodList("MCWidgetGetMyName", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_286_0)
    MakeCustomInvokeList("MyName", "com.livecode.widget", MethodList_286_0, List_Nil -> List_269_1)
    DefineCustomInvokeList(269, List_269_1)
    MakeCustomInvokeMethodList("MCWidgetGetMyScriptObject", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_287_0)
    MakeCustomInvokeList("MyScriptObject", "com.livecode.widget", MethodList_287_0, List_Nil -> List_270_1)
    DefineCustomInvokeList(270, List_270_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_288_1)
    MakeCustomInvokeMethodList("MCWidgetExecTriggerAllInWidget", Execute_Type,   MethodListArgs_288_1, MethodList_Nil -> MethodList_288_1)
    MakeCustomInvokeMethodList("MCWidgetExecTriggerAll", Execute_Type,  Signature_Nil, MethodList_288_1 -> MethodList_288_0)
    MakeCustomInvokeList("TriggerAll", "com.livecode.widget", MethodList_288_0, List_Nil -> List_271_1)
    DefineCustomInvokeList(271, List_271_1)
    MakeCustomInvokeMethodList("MCWidgetEvalInEditMode", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_289_0)
    MakeCustomInvokeList("IsEditMode", "com.livecode.widget", MethodList_289_0, List_Nil -> List_273_1)
    DefineCustomInvokeList(273, List_273_1)
    MakeCustomInvokeMethodList("MCWidgetExecCancelTimer", Execute_Type,  Signature_Nil, MethodList_Nil -> MethodList_290_0)
    MakeCustomInvokeList("CancelTimer", "com.livecode.widget", MethodList_290_0, List_Nil -> List_274_1)
    DefineCustomInvokeList(274, List_274_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_291_0)
    MakeCustomInvokeMethodList("MCWidgetExecScheduleTimerIn", Execute_Type,   MethodListArgs_291_0, MethodList_Nil -> MethodList_291_0)
    MakeCustomInvokeList("ScheduleTimerIn", "com.livecode.widget", MethodList_291_0, List_Nil -> List_275_1)
    DefineCustomInvokeList(275, List_275_1)
    MakeCustomInvokeMethodList("MCWidgetExecRedrawAll", Execute_Type,  Signature_Nil, MethodList_Nil -> MethodList_292_0)
    MakeCustomInvokeList("RedrawAll", "com.livecode.widget", MethodList_292_0, List_Nil -> List_276_1)
    DefineCustomInvokeList(276, List_276_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_293_1)
    MakeCustomInvokeMethodList("MCEngineExecResolveFilePathRelativeToObject", Execute_Type,   MethodListArgs_293_1, MethodList_Nil -> MethodList_293_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_293_0)
    MakeCustomInvokeMethodList("MCEngineExecResolveFilePath", Execute_Type,   MethodListArgs_293_0, MethodList_293_1 -> MethodList_293_0)
    MakeCustomInvokeList("ResolveFilePath", "com.livecode.engine", MethodList_293_0, List_Nil -> List_277_1)
    DefineCustomInvokeList(277, List_277_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_294_0)
    MakeCustomInvokeMethodList("MCEngineEvalKeyIsDown", Evaluate_Type,   MethodListArgs_294_0, MethodList_Nil -> MethodList_294_0)
    MakeCustomInvokeList("KeyIsDown", "com.livecode.engine", MethodList_294_0, List_Nil -> List_279_1)
    DefineCustomInvokeList(279, List_279_1)
    MakeCustomInvokeMethodList("MCEngineEvalMyResourcesFolder", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_295_0)
    MakeCustomInvokeList("MyResourcesFolder", "com.livecode.engine", MethodList_295_0, List_Nil -> List_282_1)
    DefineCustomInvokeList(282, List_282_1)
    InitializeCustomInvokeLists_250

'action' InitializeCustomInvokeLists_250
  'rule' InitializeCustomInvokeLists_250
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodList("MCEngineEvalTheItemDelimiter", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_296_0)
    MakeCustomInvokeList("TheItemDelimiter", "com.livecode.engine", MethodList_296_0, List_Nil -> List_283_1)
    DefineCustomInvokeList(283, List_283_1)
    MakeCustomInvokeMethodList("MCEngineEvalTheLineDelimiter", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_297_0)
    MakeCustomInvokeList("TheLineDelimiter", "com.livecode.engine", MethodList_297_0, List_Nil -> List_284_1)
    DefineCustomInvokeList(284, List_284_1)
    MakeCustomInvokeMethodList("MCEngineEvalTheRowDelimiter", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_298_0)
    MakeCustomInvokeList("TheRowDelimiter", "com.livecode.engine", MethodList_298_0, List_Nil -> List_285_1)
    DefineCustomInvokeList(285, List_285_1)
    MakeCustomInvokeMethodList("MCEngineEvalTheColumnDelimiter", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_299_0)
    MakeCustomInvokeList("TheColumnDelimiter", "com.livecode.engine", MethodList_299_0, List_Nil -> List_286_1)
    DefineCustomInvokeList(286, List_286_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_300_1)
    MakeCustomInvokeMethodList("MCEngineExecLogWithValues", Execute_Type,   MethodListArgs_300_1, MethodList_Nil -> MethodList_300_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_300_0)
    MakeCustomInvokeMethodList("MCEngineExecLog", Execute_Type,   MethodListArgs_300_0, MethodList_300_1 -> MethodList_300_0)
    MakeCustomInvokeList("Log", "com.livecode.engine", MethodList_300_0, List_Nil -> List_287_1)
    DefineCustomInvokeList(287, List_287_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_301_3)
    MakeCustomInvokeMethodList("MCEngineExecExecuteScriptInScriptObjectWithArguments", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_301_3)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 2 -> MethodListArgs_301_2)
    MakeCustomInvokeMethodList("MCEngineExecExecuteScriptWithArguments", Execute_Type,   MethodListArgs_301_2, MethodList_301_3 -> MethodList_301_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_301_1)
    MakeCustomInvokeMethodList("MCEngineExecExecuteScriptInScriptObject", Execute_Type,   MethodListArgs_301_1, MethodList_301_2 -> MethodList_301_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_301_0)
    MakeCustomInvokeMethodList("MCEngineExecExecuteScript", Execute_Type,   MethodListArgs_301_0, MethodList_301_1 -> MethodList_301_0)
    MakeCustomInvokeList("ExecuteScript", "com.livecode.engine", MethodList_301_0, List_Nil -> List_289_1)
    DefineCustomInvokeList(289, List_289_1)
    MakeCustomInvokeMethodList("MCEngineEvalCaller", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_302_0)
    MakeCustomInvokeList("Caller", "com.livecode.engine", MethodList_302_0, List_Nil -> List_292_1)
    DefineCustomInvokeList(292, List_292_1)
    MakeCustomInvokeMethodList("MCEngineEvalMessageWasNotHandled", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_303_0)
    MakeCustomInvokeList("MessageWasNotHandled", "com.livecode.engine", MethodList_303_0, List_Nil -> List_293_1)
    DefineCustomInvokeList(293, List_293_1)
    MakeCustomInvokeMethodList("MCEngineEvalMessageWasHandled", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_304_0)
    MakeCustomInvokeList("MessageWasHandled", "com.livecode.engine", MethodList_304_0, List_Nil -> List_294_1)
    DefineCustomInvokeList(294, List_294_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_305_3)
    MakeCustomInvokeMethodList("MCEngineExecPostToScriptObjectWithArguments", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_305_3)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_305_2)
    MakeCustomInvokeMethodList("MCEngineExecPostToScriptObject", Execute_Type,   MethodListArgs_305_2, MethodList_305_3 -> MethodList_305_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 2 -> MethodListArgs_305_1)
    MakeCustomInvokeMethodList("MCEngineExecPostWithArguments", Execute_Type,   MethodListArgs_305_1, MethodList_305_2 -> MethodList_305_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_305_0)
    MakeCustomInvokeMethodList("MCEngineExecPost", Execute_Type,   MethodListArgs_305_0, MethodList_305_1 -> MethodList_305_0)
    MakeCustomInvokeList("PostToScriptObject", "com.livecode.engine", MethodList_305_0, List_Nil -> List_295_1)
    DefineCustomInvokeList(295, List_295_1)
    InitializeCustomInvokeLists_260

'action' InitializeCustomInvokeLists_260
  'rule' InitializeCustomInvokeLists_260
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodList("MCEngineExecSendToScriptObjectWithArguments", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_306_3)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_306_2)
    MakeCustomInvokeMethodList("MCEngineExecSendToScriptObject", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_306_3 -> MethodList_306_2)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 3 -> MethodListArgs_306_1)
    MakeCustomInvokeMethodList("MCEngineExecSendWithArguments", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 3, Signature_Nil))), MethodList_306_2 -> MethodList_306_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_306_0)
    MakeCustomInvokeMethodList("MCEngineExecSend", Execute_Type,   MethodListArgs_306_0, MethodList_306_1 -> MethodList_306_0)
    MakeCustomInvokeList("SendToScriptObject", "com.livecode.engine", MethodList_306_0, List_Nil -> List_298_1)
    DefineCustomInvokeList(298, List_298_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_307_0)
    MakeCustomInvokeMethodList("MCEngineEvalChildrenOfScriptObject", Evaluate_Type,   MethodListArgs_307_0, MethodList_Nil -> MethodList_307_0)
    MakeCustomInvokeList("ChildrenOfScriptObject", "com.livecode.engine", MethodList_307_0, List_Nil -> List_302_1)
    DefineCustomInvokeList(302, List_302_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_308_0)
    MakeCustomInvokeMethodList("MCEngineEvalOwnerOfScriptObject", Evaluate_Type,   MethodListArgs_308_0, MethodList_Nil -> MethodList_308_0)
    MakeCustomInvokeList("OwnerOfScriptObject", "com.livecode.engine", MethodList_308_0, List_Nil -> List_303_1)
    DefineCustomInvokeList(303, List_303_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_309_1)
    MakeCustomInvokeMethodList("MCWidgetSetPropertyOfWidget", Assign_Type,   MethodListArgs_309_1, MethodList_Nil -> MethodList_309_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_309_0)
    MakeCustomInvokeMethodList("MCWidgetGetPropertyOfWidget", Evaluate_Type,   MethodListArgs_309_0, MethodList_309_1 -> MethodList_309_0)
    MakeCustomInvokeList("PropertyOfWidget", "com.livecode.widget", MethodList_309_0, List_Nil -> List_304_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_310_1)
    MakeCustomInvokeMethodList("MCEngineExecSetPropertyOfScriptObject", Assign_Type,   MethodListArgs_310_1, MethodList_Nil -> MethodList_310_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_310_0)
    MakeCustomInvokeMethodList("MCEngineExecGetPropertyOfScriptObject", Evaluate_Type,   MethodListArgs_310_0, MethodList_310_1 -> MethodList_310_0)
    MakeCustomInvokeList("PropertyOfScriptObject", "com.livecode.engine", MethodList_310_0, List_304_1 -> List_304_2)
    DefineCustomInvokeList(304, List_304_2)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_311_0)
    MakeCustomInvokeMethodList("MCEngineEvalScriptObjectDoesNotExist", Evaluate_Type,   MethodListArgs_311_0, MethodList_Nil -> MethodList_311_0)
    MakeCustomInvokeList("ScriptObjectDoesNotExist", "com.livecode.engine", MethodList_311_0, List_Nil -> List_305_1)
    DefineCustomInvokeList(305, List_305_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_312_0)
    MakeCustomInvokeMethodList("MCEngineEvalScriptObjectExists", Evaluate_Type,   MethodListArgs_312_0, MethodList_Nil -> MethodList_312_0)
    MakeCustomInvokeList("ScriptObjectExists", "com.livecode.engine", MethodList_312_0, List_Nil -> List_306_1)
    DefineCustomInvokeList(306, List_306_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_313_0)
    MakeCustomInvokeMethodList("MCEngineExecResolveScriptObject", Execute_Type,   MethodListArgs_313_0, MethodList_Nil -> MethodList_313_0)
    MakeCustomInvokeList("ResolveScriptObject", "com.livecode.engine", MethodList_313_0, List_Nil -> List_307_1)
    DefineCustomInvokeList(307, List_307_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_314_0)
    MakeCustomInvokeMethodList("MCCanvasGetPixelHeightOfCanvas", Evaluate_Type,   MethodListArgs_314_0, MethodList_Nil -> MethodList_314_0)
    MakeCustomInvokeList("GetPixelHeightOfCanvas", "com.livecode.canvas", MethodList_314_0, List_Nil -> List_308_1)
    DefineCustomInvokeList(308, List_308_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_315_0)
    MakeCustomInvokeMethodList("MCCanvasGetPixelWidthOfCanvas", Evaluate_Type,   MethodListArgs_315_0, MethodList_Nil -> MethodList_315_0)
    MakeCustomInvokeList("GetPixelWidthOfCanvas", "com.livecode.canvas", MethodList_315_0, List_Nil -> List_309_1)
    DefineCustomInvokeList(309, List_309_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_316_0)
    MakeCustomInvokeMethodList("MCCanvasGetPixelDataOfCanvas", Evaluate_Type,   MethodListArgs_316_0, MethodList_Nil -> MethodList_316_0)
    MakeCustomInvokeList("GetPixelDataOfCanvas", "com.livecode.canvas", MethodList_316_0, List_Nil -> List_310_1)
    DefineCustomInvokeList(310, List_310_1)
    InitializeCustomInvokeLists_270

'action' InitializeCustomInvokeLists_270
  'rule' InitializeCustomInvokeLists_270
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_317_0)
    MakeCustomInvokeMethodList("MCCanvasNewCanvasWithSize", Evaluate_Type,   MethodListArgs_317_0, MethodList_Nil -> MethodList_317_0)
    MakeCustomInvokeList("NewCanvasWithSize", "com.livecode.canvas", MethodList_317_0, List_Nil -> List_311_1)
    DefineCustomInvokeList(311, List_311_1)
    MakeCustomInvokeMethodList("MCCanvasPretendToAssignToThisCanvas", Assign_Type,  Signature_Nil, MethodList_Nil -> MethodList_318_1)
    MakeCustomInvokeMethodList("MCCanvasThisCanvas", Evaluate_Type,  Signature_Nil, MethodList_318_1 -> MethodList_318_0)
    MakeCustomInvokeList("ThisCanvas", "com.livecode.canvas", MethodList_318_0, List_Nil -> List_312_1)
    DefineCustomInvokeList(312, List_312_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_319_0)
    MakeCustomInvokeMethodList("MCCanvasMeasureText", Execute_Type,   MethodListArgs_319_0, MethodList_Nil -> MethodList_319_0)
    MakeCustomInvokeList("CanvasOperationMeasureText", "com.livecode.canvas", MethodList_319_0, List_Nil -> List_313_1)
    DefineCustomInvokeList(313, List_313_1)
    MakeCustomInvokeMethodList("MCCanvasFillTextAligned", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_320_0)
    MakeCustomInvokeList("CanvasOperationFillTextAligned", "com.livecode.canvas", MethodList_320_0, List_Nil -> List_314_1)
    DefineCustomInvokeList(314, List_314_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_321_0)
    MakeCustomInvokeMethodList("MCCanvasFillText", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_321_0)
    MakeCustomInvokeList("CanvasOperationFillText", "com.livecode.canvas", MethodList_321_0, List_Nil -> List_315_1)
    DefineCustomInvokeList(315, List_315_1)
    MakeCustomInvokeMethodList("MCCanvasDrawRectOfImage", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_322_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 1, In_Mode, 2, In_Mode, 3 -> MethodListArgs_322_0)
    MakeCustomInvokeMethodList("MCCanvasDrawImage", Execute_Type, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil))), MethodList_322_1 -> MethodList_322_0)
    MakeCustomInvokeList("CanvasOperationDrawImage", "com.livecode.canvas", MethodList_322_0, List_Nil -> List_316_1)
    DefineCustomInvokeList(316, List_316_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_323_0)
    MakeCustomInvokeMethodList("MCCanvasClipToPath", Execute_Type,   MethodListArgs_323_0, MethodList_Nil -> MethodList_323_0)
    MakeCustomInvokeList("CanvasOperationClipPath", "com.livecode.canvas", MethodList_323_0, List_Nil -> List_318_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_324_0)
    MakeCustomInvokeMethodList("MCCanvasClipToRect", Execute_Type,   MethodListArgs_324_0, MethodList_Nil -> MethodList_324_0)
    MakeCustomInvokeList("CanvasOperationClip", "com.livecode.canvas", MethodList_324_0, List_318_1 -> List_318_2)
    DefineCustomInvokeList(318, List_318_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_325_1)
    MakeCustomInvokeMethodList("MCCanvasStrokePath", Execute_Type,   MethodListArgs_325_1, MethodList_Nil -> MethodList_325_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 1 -> MethodListArgs_325_0)
    MakeCustomInvokeMethodList("MCCanvasStroke", Execute_Type,   MethodListArgs_325_0, MethodList_325_1 -> MethodList_325_0)
    MakeCustomInvokeList("CanvasOperationStroke", "com.livecode.canvas", MethodList_325_0, List_Nil -> List_319_1)
    DefineCustomInvokeList(319, List_319_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_326_1)
    MakeCustomInvokeMethodList("MCCanvasFillPath", Execute_Type,   MethodListArgs_326_1, MethodList_Nil -> MethodList_326_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 1 -> MethodListArgs_326_0)
    MakeCustomInvokeMethodList("MCCanvasFill", Execute_Type,   MethodListArgs_326_0, MethodList_326_1 -> MethodList_326_0)
    MakeCustomInvokeList("CanvasOperationFill", "com.livecode.canvas", MethodList_326_0, List_Nil -> List_321_1)
    DefineCustomInvokeList(321, List_321_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_327_0)
    MakeCustomInvokeMethodList("MCCanvasEndLayer", Execute_Type,   MethodListArgs_327_0, MethodList_Nil -> MethodList_327_0)
    MakeCustomInvokeList("CanvasOperationEndLayer", "com.livecode.canvas", MethodList_327_0, List_Nil -> List_323_1)
    DefineCustomInvokeList(323, List_323_1)
    InitializeCustomInvokeLists_280

'action' InitializeCustomInvokeLists_280
  'rule' InitializeCustomInvokeLists_280
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_328_0)
    MakeCustomInvokeMethodList("MCCanvasBeginEffectOnlyLayerWithEffect", Execute_Type,   MethodListArgs_328_0, MethodList_Nil -> MethodList_328_0)
    MakeCustomInvokeList("CanvasOperationBeginEffectOnlyLayer", "com.livecode.canvas", MethodList_328_0, List_Nil -> List_324_1)
    DefineCustomInvokeList(324, List_324_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_329_1)
    MakeCustomInvokeMethodList("MCCanvasBeginLayerWithEffect", Execute_Type,   MethodListArgs_329_1, MethodList_Nil -> MethodList_329_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 1 -> MethodListArgs_329_0)
    MakeCustomInvokeMethodList("MCCanvasBeginLayer", Execute_Type,   MethodListArgs_329_0, MethodList_329_1 -> MethodList_329_0)
    MakeCustomInvokeList("CanvasOperationBeginLayer", "com.livecode.canvas", MethodList_329_0, List_Nil -> List_325_1)
    DefineCustomInvokeList(325, List_325_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_330_0)
    MakeCustomInvokeMethodList("MCCanvasRestoreState", Execute_Type,   MethodListArgs_330_0, MethodList_Nil -> MethodList_330_0)
    MakeCustomInvokeList("CanvasOperationRestoreState", "com.livecode.canvas", MethodList_330_0, List_Nil -> List_327_1)
    DefineCustomInvokeList(327, List_327_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_331_0)
    MakeCustomInvokeMethodList("MCCanvasSaveState", Execute_Type,   MethodListArgs_331_0, MethodList_Nil -> MethodList_331_0)
    MakeCustomInvokeList("CanvasOperationSaveState", "com.livecode.canvas", MethodList_331_0, List_Nil -> List_328_1)
    DefineCustomInvokeList(328, List_328_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_332_0)
    MakeCustomInvokeMethodList("MCCanvasGetClipBounds", Evaluate_Type,   MethodListArgs_332_0, MethodList_Nil -> MethodList_332_0)
    MakeCustomInvokeList("CanvasPropertyClippingBounds", "com.livecode.canvas", MethodList_332_0, List_Nil -> List_329_1)
    DefineCustomInvokeList(329, List_329_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_333_1)
    MakeCustomInvokeMethodList("MCCanvasSetDashPhase", Assign_Type,   MethodListArgs_333_1, MethodList_Nil -> MethodList_333_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_333_0)
    MakeCustomInvokeMethodList("MCCanvasGetDashPhase", Evaluate_Type,   MethodListArgs_333_0, MethodList_333_1 -> MethodList_333_0)
    MakeCustomInvokeList("CanvasPropertyDashPhase", "com.livecode.canvas", MethodList_333_0, List_Nil -> List_330_1)
    DefineCustomInvokeList(330, List_330_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_334_1)
    MakeCustomInvokeMethodList("MCCanvasSetDashes", Assign_Type,   MethodListArgs_334_1, MethodList_Nil -> MethodList_334_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_334_0)
    MakeCustomInvokeMethodList("MCCanvasGetDashes", Evaluate_Type,   MethodListArgs_334_0, MethodList_334_1 -> MethodList_334_0)
    MakeCustomInvokeList("CanvasPropertyDashes", "com.livecode.canvas", MethodList_334_0, List_Nil -> List_331_1)
    DefineCustomInvokeList(331, List_331_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_335_1)
    MakeCustomInvokeMethodList("MCCanvasSetMiterLimit", Assign_Type,   MethodListArgs_335_1, MethodList_Nil -> MethodList_335_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_335_0)
    MakeCustomInvokeMethodList("MCCanvasGetMiterLimit", Evaluate_Type,   MethodListArgs_335_0, MethodList_335_1 -> MethodList_335_0)
    MakeCustomInvokeList("CanvasPropertyMiterLimit", "com.livecode.canvas", MethodList_335_0, List_Nil -> List_332_1)
    DefineCustomInvokeList(332, List_332_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_336_1)
    MakeCustomInvokeMethodList("MCCanvasSetCapStyleAsString", Assign_Type,   MethodListArgs_336_1, MethodList_Nil -> MethodList_336_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_336_0)
    MakeCustomInvokeMethodList("MCCanvasGetCapStyleAsString", Evaluate_Type,   MethodListArgs_336_0, MethodList_336_1 -> MethodList_336_0)
    MakeCustomInvokeList("CanvasPropertyCapStyle", "com.livecode.canvas", MethodList_336_0, List_Nil -> List_333_1)
    DefineCustomInvokeList(333, List_333_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_337_1)
    MakeCustomInvokeMethodList("MCCanvasSetJoinStyleAsString", Assign_Type,   MethodListArgs_337_1, MethodList_Nil -> MethodList_337_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_337_0)
    MakeCustomInvokeMethodList("MCCanvasGetJoinStyleAsString", Evaluate_Type,   MethodListArgs_337_0, MethodList_337_1 -> MethodList_337_0)
    MakeCustomInvokeList("CanvasPropertyJoinStyle", "com.livecode.canvas", MethodList_337_0, List_Nil -> List_334_1)
    DefineCustomInvokeList(334, List_334_1)
    InitializeCustomInvokeLists_290

'action' InitializeCustomInvokeLists_290
  'rule' InitializeCustomInvokeLists_290
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_338_1)
    MakeCustomInvokeMethodList("MCCanvasSetFont", Assign_Type,   MethodListArgs_338_1, MethodList_Nil -> MethodList_338_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_338_0)
    MakeCustomInvokeMethodList("MCCanvasGetFont", Evaluate_Type,   MethodListArgs_338_0, MethodList_338_1 -> MethodList_338_0)
    MakeCustomInvokeList("CanvasPropertyFont", "com.livecode.canvas", MethodList_338_0, List_Nil -> List_335_1)
    DefineCustomInvokeList(335, List_335_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_339_1)
    MakeCustomInvokeMethodList("MCCanvasSetStrokeWidth", Assign_Type,   MethodListArgs_339_1, MethodList_Nil -> MethodList_339_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_339_0)
    MakeCustomInvokeMethodList("MCCanvasGetStrokeWidth", Evaluate_Type,   MethodListArgs_339_0, MethodList_339_1 -> MethodList_339_0)
    MakeCustomInvokeList("CanvasPropertyStrokeWidth", "com.livecode.canvas", MethodList_339_0, List_Nil -> List_336_1)
    DefineCustomInvokeList(336, List_336_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_340_1)
    MakeCustomInvokeMethodList("MCCanvasSetImageResizeQualityAsString", Assign_Type,   MethodListArgs_340_1, MethodList_Nil -> MethodList_340_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_340_0)
    MakeCustomInvokeMethodList("MCCanvasGetImageResizeQualityAsString", Evaluate_Type,   MethodListArgs_340_0, MethodList_340_1 -> MethodList_340_0)
    MakeCustomInvokeList("CanvasPropertyImageResizeQuality", "com.livecode.canvas", MethodList_340_0, List_Nil -> List_337_1)
    DefineCustomInvokeList(337, List_337_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_341_1)
    MakeCustomInvokeMethodList("MCCanvasSetStippled", Assign_Type,   MethodListArgs_341_1, MethodList_Nil -> MethodList_341_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_341_0)
    MakeCustomInvokeMethodList("MCCanvasGetStippled", Evaluate_Type,   MethodListArgs_341_0, MethodList_341_1 -> MethodList_341_0)
    MakeCustomInvokeList("CanvasPropertyStippled", "com.livecode.canvas", MethodList_341_0, List_Nil -> List_338_1)
    DefineCustomInvokeList(338, List_338_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_342_1)
    MakeCustomInvokeMethodList("MCCanvasSetOpacity", Assign_Type,   MethodListArgs_342_1, MethodList_Nil -> MethodList_342_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_342_0)
    MakeCustomInvokeMethodList("MCCanvasGetOpacity", Evaluate_Type,   MethodListArgs_342_0, MethodList_342_1 -> MethodList_342_0)
    MakeCustomInvokeList("CanvasPropertyOpacity", "com.livecode.canvas", MethodList_342_0, List_Nil -> List_339_1)
    DefineCustomInvokeList(339, List_339_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_343_1)
    MakeCustomInvokeMethodList("MCCanvasSetAntialias", Assign_Type,   MethodListArgs_343_1, MethodList_Nil -> MethodList_343_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_343_0)
    MakeCustomInvokeMethodList("MCCanvasGetAntialias", Evaluate_Type,   MethodListArgs_343_0, MethodList_343_1 -> MethodList_343_0)
    MakeCustomInvokeList("CanvasPropertyAntialias", "com.livecode.canvas", MethodList_343_0, List_Nil -> List_340_1)
    DefineCustomInvokeList(340, List_340_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_344_1)
    MakeCustomInvokeMethodList("MCCanvasSetFillRuleAsString", Assign_Type,   MethodListArgs_344_1, MethodList_Nil -> MethodList_344_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_344_0)
    MakeCustomInvokeMethodList("MCCanvasGetFillRuleAsString", Evaluate_Type,   MethodListArgs_344_0, MethodList_344_1 -> MethodList_344_0)
    MakeCustomInvokeList("CanvasPropertyFillRule", "com.livecode.canvas", MethodList_344_0, List_Nil -> List_341_1)
    DefineCustomInvokeList(341, List_341_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_345_1)
    MakeCustomInvokeMethodList("MCCanvasSetPaint", Assign_Type,   MethodListArgs_345_1, MethodList_Nil -> MethodList_345_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_345_0)
    MakeCustomInvokeMethodList("MCCanvasGetPaint", Evaluate_Type,   MethodListArgs_345_0, MethodList_345_1 -> MethodList_345_0)
    MakeCustomInvokeList("CanvasPropertyPaint", "com.livecode.canvas", MethodList_345_0, List_Nil -> List_342_1)
    DefineCustomInvokeList(342, List_342_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_346_0)
    MakeCustomInvokeMethodList("MCCanvasAlignmentEvaluate", Evaluate_Type,   MethodListArgs_346_0, MethodList_Nil -> MethodList_346_0)
    MakeCustomInvokeList("CanvasTextAlignment", "com.livecode.canvas", MethodList_346_0, List_Nil -> List_343_1)
    DefineCustomInvokeList(343, List_343_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_347_0)
    MakeCustomInvokeMethodList("MCCanvasFontMeasureTextImageBoundsOnCanvas", Evaluate_Type,   MethodListArgs_347_0, MethodList_Nil -> MethodList_347_0)
    MakeCustomInvokeList("FontOperationTextImageBoundsOnCanvas", "com.livecode.canvas", MethodList_347_0, List_Nil -> List_344_1)
    DefineCustomInvokeList(344, List_344_1)
    InitializeCustomInvokeLists_300

'action' InitializeCustomInvokeLists_300
  'rule' InitializeCustomInvokeLists_300
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_348_0)
    MakeCustomInvokeMethodList("MCCanvasFontMeasureTextImageBounds", Evaluate_Type,   MethodListArgs_348_0, MethodList_Nil -> MethodList_348_0)
    MakeCustomInvokeList("FontOperationTextImageBounds", "com.livecode.canvas", MethodList_348_0, List_Nil -> List_345_1)
    DefineCustomInvokeList(345, List_345_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_349_0)
    MakeCustomInvokeMethodList("MCCanvasFontMeasureTextTypographicBoundsOnCanvas", Evaluate_Type,   MethodListArgs_349_0, MethodList_Nil -> MethodList_349_0)
    MakeCustomInvokeList("FontOperationTextLayoutBoundsOnCanvas", "com.livecode.canvas", MethodList_349_0, List_Nil -> List_346_1)
    DefineCustomInvokeList(346, List_346_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_350_0)
    MakeCustomInvokeMethodList("MCCanvasFontMeasureTextTypographicBounds", Evaluate_Type,   MethodListArgs_350_0, MethodList_Nil -> MethodList_350_0)
    MakeCustomInvokeList("FontOperationTextLayoutBounds", "com.livecode.canvas", MethodList_350_0, List_Nil -> List_348_1)
    DefineCustomInvokeList(348, List_348_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_351_1)
    MakeCustomInvokeMethodList("MCCanvasFontSetItalic", Assign_Type,   MethodListArgs_351_1, MethodList_Nil -> MethodList_351_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_351_0)
    MakeCustomInvokeMethodList("MCCanvasFontGetItalic", Evaluate_Type,   MethodListArgs_351_0, MethodList_351_1 -> MethodList_351_0)
    MakeCustomInvokeList("FontPropertyItalic", "com.livecode.canvas", MethodList_351_0, List_Nil -> List_350_1)
    DefineCustomInvokeList(350, List_350_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_352_1)
    MakeCustomInvokeMethodList("MCCanvasFontSetBold", Assign_Type,   MethodListArgs_352_1, MethodList_Nil -> MethodList_352_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_352_0)
    MakeCustomInvokeMethodList("MCCanvasFontGetBold", Evaluate_Type,   MethodListArgs_352_0, MethodList_352_1 -> MethodList_352_0)
    MakeCustomInvokeList("FontPropertyBold", "com.livecode.canvas", MethodList_352_0, List_Nil -> List_351_1)
    DefineCustomInvokeList(351, List_351_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_353_1)
    MakeCustomInvokeMethodList("MCCanvasFontSetName", Assign_Type,   MethodListArgs_353_1, MethodList_Nil -> MethodList_353_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_353_0)
    MakeCustomInvokeMethodList("MCCanvasFontGetName", Evaluate_Type,   MethodListArgs_353_0, MethodList_353_1 -> MethodList_353_0)
    MakeCustomInvokeList("FontPropertyName", "com.livecode.canvas", MethodList_353_0, List_Nil -> List_352_1)
    DefineCustomInvokeList(352, List_352_1)
    MakeCustomInvokeMethodList("MCCanvasFontMakeWithSize", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_354_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_354_0)
    MakeCustomInvokeMethodList("MCCanvasFontMakeWithStyle", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_354_1 -> MethodList_354_0)
    MakeCustomInvokeList("FontMakeWithStyleAndSize", "com.livecode.canvas", MethodList_354_0, List_Nil -> List_353_1)
    DefineCustomInvokeList(353, List_353_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_355_0)
    MakeCustomInvokeMethodList("MCCanvasFontMakeWithStyle", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_Nil -> MethodList_355_0)
    MakeCustomInvokeList("FontMakeWithStyle", "com.livecode.canvas", MethodList_355_0, List_Nil -> List_355_1)
    DefineCustomInvokeList(355, List_355_1)
    MakeCustomInvokeMethodList("MCCanvasFontMakeWithSize", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_356_0)
    MakeCustomInvokeList("FontMakeWithSize", "com.livecode.canvas", MethodList_356_0, List_Nil -> List_357_1)
    DefineCustomInvokeList(357, List_357_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_357_0)
    MakeCustomInvokeMethodList("MCCanvasFontMake", Evaluate_Type,   MethodListArgs_357_0, MethodList_Nil -> MethodList_357_0)
    MakeCustomInvokeList("FontMake", "com.livecode.canvas", MethodList_357_0, List_Nil -> List_358_1)
    DefineCustomInvokeList(358, List_358_1)
    InitializeCustomInvokeLists_310

'action' InitializeCustomInvokeLists_310
  'rule' InitializeCustomInvokeLists_310
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_358_1)
    MakeCustomInvokeMethodList("MCCanvasEffectSetSourceAsString", Assign_Type,   MethodListArgs_358_1, MethodList_Nil -> MethodList_358_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_358_0)
    MakeCustomInvokeMethodList("MCCanvasEffectGetSourceAsString", Evaluate_Type,   MethodListArgs_358_0, MethodList_358_1 -> MethodList_358_0)
    MakeCustomInvokeList("EffectPropertySource", "com.livecode.canvas", MethodList_358_0, List_Nil -> List_359_1)
    DefineCustomInvokeList(359, List_359_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_359_1)
    MakeCustomInvokeMethodList("MCCanvasEffectSetKnockOut", Assign_Type,   MethodListArgs_359_1, MethodList_Nil -> MethodList_359_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_359_0)
    MakeCustomInvokeMethodList("MCCanvasEffectGetKnockOut", Evaluate_Type,   MethodListArgs_359_0, MethodList_359_1 -> MethodList_359_0)
    MakeCustomInvokeList("EffectPropertyKnockOut", "com.livecode.canvas", MethodList_359_0, List_Nil -> List_360_1)
    DefineCustomInvokeList(360, List_360_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_360_1)
    MakeCustomInvokeMethodList("MCCanvasEffectSetAngle", Assign_Type,   MethodListArgs_360_1, MethodList_Nil -> MethodList_360_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_360_0)
    MakeCustomInvokeMethodList("MCCanvasEffectGetAngle", Evaluate_Type,   MethodListArgs_360_0, MethodList_360_1 -> MethodList_360_0)
    MakeCustomInvokeList("EffectPropertyAngle", "com.livecode.canvas", MethodList_360_0, List_Nil -> List_361_1)
    DefineCustomInvokeList(361, List_361_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_361_1)
    MakeCustomInvokeMethodList("MCCanvasEffectSetDistance", Assign_Type,   MethodListArgs_361_1, MethodList_Nil -> MethodList_361_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_361_0)
    MakeCustomInvokeMethodList("MCCanvasEffectGetDistance", Evaluate_Type,   MethodListArgs_361_0, MethodList_361_1 -> MethodList_361_0)
    MakeCustomInvokeList("EffectPropertyDistance", "com.livecode.canvas", MethodList_361_0, List_Nil -> List_362_1)
    DefineCustomInvokeList(362, List_362_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_362_1)
    MakeCustomInvokeMethodList("MCCanvasEffectSetSpread", Assign_Type,   MethodListArgs_362_1, MethodList_Nil -> MethodList_362_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_362_0)
    MakeCustomInvokeMethodList("MCCanvasEffectGetSpread", Evaluate_Type,   MethodListArgs_362_0, MethodList_362_1 -> MethodList_362_0)
    MakeCustomInvokeList("EffectPropertySpread", "com.livecode.canvas", MethodList_362_0, List_Nil -> List_363_1)
    DefineCustomInvokeList(363, List_363_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_363_1)
    MakeCustomInvokeMethodList("MCCanvasFontSetSize", Assign_Type,   MethodListArgs_363_1, MethodList_Nil -> MethodList_363_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_363_0)
    MakeCustomInvokeMethodList("MCCanvasFontGetSize", Evaluate_Type,   MethodListArgs_363_0, MethodList_363_1 -> MethodList_363_0)
    MakeCustomInvokeList("FontPropertySize", "com.livecode.canvas", MethodList_363_0, List_Nil -> List_364_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_364_1)
    MakeCustomInvokeMethodList("MCCanvasEffectSetSize", Assign_Type,   MethodListArgs_364_1, MethodList_Nil -> MethodList_364_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_364_0)
    MakeCustomInvokeMethodList("MCCanvasEffectGetSize", Evaluate_Type,   MethodListArgs_364_0, MethodList_364_1 -> MethodList_364_0)
    MakeCustomInvokeList("EffectPropertySize", "com.livecode.canvas", MethodList_364_0, List_364_1 -> List_364_2)
    DefineCustomInvokeList(364, List_364_2)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_365_1)
    MakeCustomInvokeMethodList("MCCanvasSetBlendModeAsString", Assign_Type,   MethodListArgs_365_1, MethodList_Nil -> MethodList_365_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_365_0)
    MakeCustomInvokeMethodList("MCCanvasGetBlendModeAsString", Evaluate_Type,   MethodListArgs_365_0, MethodList_365_1 -> MethodList_365_0)
    MakeCustomInvokeList("CanvasPropertyBlendMode", "com.livecode.canvas", MethodList_365_0, List_Nil -> List_365_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_366_1)
    MakeCustomInvokeMethodList("MCCanvasEffectSetBlendModeAsString", Assign_Type,   MethodListArgs_366_1, MethodList_Nil -> MethodList_366_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_366_0)
    MakeCustomInvokeMethodList("MCCanvasEffectGetBlendModeAsString", Evaluate_Type,   MethodListArgs_366_0, MethodList_366_1 -> MethodList_366_0)
    MakeCustomInvokeList("EffectPropertyBlendMode", "com.livecode.canvas", MethodList_366_0, List_365_1 -> List_365_2)
    DefineCustomInvokeList(365, List_365_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_367_0)
    MakeCustomInvokeMethodList("MCCanvasEffectMakeWithPropertyArray", Evaluate_Type,   MethodListArgs_367_0, MethodList_Nil -> MethodList_367_0)
    MakeCustomInvokeList("EffectMakeWithProperties", "com.livecode.canvas", MethodList_367_0, List_Nil -> List_366_1)
    DefineCustomInvokeList(366, List_366_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_368_0)
    MakeCustomInvokeMethodList("MCCanvasEffectMake", Evaluate_Type,   MethodListArgs_368_0, MethodList_Nil -> MethodList_368_0)
    MakeCustomInvokeList("EffectMake", "com.livecode.canvas", MethodList_368_0, List_Nil -> List_367_1)
    DefineCustomInvokeList(367, List_367_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_369_0)
    MakeCustomInvokeMethodList("MCCanvasEffectEvaluateType", Evaluate_Type,   MethodListArgs_369_0, MethodList_Nil -> MethodList_369_0)
    MakeCustomInvokeList("EffectType", "com.livecode.canvas", MethodList_369_0, List_Nil -> List_368_1)
    DefineCustomInvokeList(368, List_368_1)
    InitializeCustomInvokeLists_320

'action' InitializeCustomInvokeLists_320
  'rule' InitializeCustomInvokeLists_320
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_370_0)
    MakeCustomInvokeMethodList("MCCanvasClosePath", Execute_Type,   MethodListArgs_370_0, MethodList_Nil -> MethodList_370_0)
    MakeCustomInvokeList("CanvasOperationClosePath", "com.livecode.canvas", MethodList_370_0, List_Nil -> List_369_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_371_0)
    MakeCustomInvokeMethodList("MCCanvasPathClosePath", Execute_Type,   MethodListArgs_371_0, MethodList_Nil -> MethodList_371_0)
    MakeCustomInvokeList("PathOperationClosePath", "com.livecode.canvas", MethodList_371_0, List_369_1 -> List_369_2)
    DefineCustomInvokeList(369, List_369_2)
    MakeCustomInvokeMethodList("MCCanvasPathEllipticArcToWithRadiiAsList", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(InOut_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_372_0)
    MakeCustomInvokeList("PathOperationEllipticArcTo", "com.livecode.canvas", MethodList_372_0, List_Nil -> List_370_1)
    DefineCustomInvokeList(370, List_370_1)
    MakeCustomInvokeMethodList("MCCanvasPathEllipticArcToWithFlagsWithRadiiAsList", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, invokesignature(In_Mode, 4, invokesignature(InOut_Mode, 5, Signature_Nil)))))), MethodList_Nil -> MethodList_373_0)
    MakeCustomInvokeList("PathOperationEllipticArcToWithFlags", "com.livecode.canvas", MethodList_373_0, List_Nil -> List_371_1)
    DefineCustomInvokeList(371, List_371_1)
    MakeCustomInvokeMethodList("MCCanvasPathArcTo", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(InOut_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_374_0)
    MakeCustomInvokeList("PathOperationArcTo", "com.livecode.canvas", MethodList_374_0, List_Nil -> List_374_1)
    DefineCustomInvokeList(374, List_374_1)
    MakeCustomInvokeMethodList("MCCanvasCurveThroughPoints", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_375_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 2, In_Mode, 3 -> MethodListArgs_375_0)
    MakeCustomInvokeMethodList("MCCanvasCurveThroughPoint", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, Signature_Nil))), MethodList_375_1 -> MethodList_375_0)
    MakeCustomInvokeList("CanvasOperationCurveThrough", "com.livecode.canvas", MethodList_375_0, List_Nil -> List_375_1)
    MakeCustomInvokeMethodList("MCCanvasPathCurveThroughPoints", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, invokesignature(InOut_Mode, 3, Signature_Nil)))), MethodList_Nil -> MethodList_376_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 2, InOut_Mode, 3 -> MethodListArgs_376_0)
    MakeCustomInvokeMethodList("MCCanvasPathCurveThroughPoint", Execute_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 2, invokesignature(InOut_Mode, 3, Signature_Nil))), MethodList_376_1 -> MethodList_376_0)
    MakeCustomInvokeList("PathOperationCurveThrough", "com.livecode.canvas", MethodList_376_0, List_375_1 -> List_375_2)
    DefineCustomInvokeList(375, List_375_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_377_0)
    MakeCustomInvokeMethodList("MCCanvasLineTo", Execute_Type,   MethodListArgs_377_0, MethodList_Nil -> MethodList_377_0)
    MakeCustomInvokeList("CanvasOperationLineTo", "com.livecode.canvas", MethodList_377_0, List_Nil -> List_377_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_378_0)
    MakeCustomInvokeMethodList("MCCanvasPathLineTo", Execute_Type,   MethodListArgs_378_0, MethodList_Nil -> MethodList_378_0)
    MakeCustomInvokeList("PathOperationLineTo", "com.livecode.canvas", MethodList_378_0, List_377_1 -> List_377_2)
    DefineCustomInvokeList(377, List_377_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_379_0)
    MakeCustomInvokeMethodList("MCCanvasMoveTo", Execute_Type,   MethodListArgs_379_0, MethodList_Nil -> MethodList_379_0)
    MakeCustomInvokeList("CanvasOperationMoveTo", "com.livecode.canvas", MethodList_379_0, List_Nil -> List_378_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_380_0)
    MakeCustomInvokeMethodList("MCCanvasPathMoveTo", Execute_Type,   MethodListArgs_380_0, MethodList_Nil -> MethodList_380_0)
    MakeCustomInvokeList("PathOperationMoveTo", "com.livecode.canvas", MethodList_380_0, List_378_1 -> List_378_2)
    DefineCustomInvokeList(378, List_378_2)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_381_0)
    MakeCustomInvokeMethodList("MCCanvasPathGetInstructionsAsString", Evaluate_Type,   MethodListArgs_381_0, MethodList_Nil -> MethodList_381_0)
    MakeCustomInvokeList("PathPropertyInstructions", "com.livecode.canvas", MethodList_381_0, List_Nil -> List_379_1)
    DefineCustomInvokeList(379, List_379_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_382_0)
    MakeCustomInvokeMethodList("MCCanvasPathGetBoundingBox", Evaluate_Type,   MethodListArgs_382_0, MethodList_Nil -> MethodList_382_0)
    MakeCustomInvokeList("PathPropertyBoundingBox", "com.livecode.canvas", MethodList_382_0, List_Nil -> List_380_1)
    DefineCustomInvokeList(380, List_380_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 2 -> MethodListArgs_383_1)
    MakeCustomInvokeMethodList("MCCanvasPathGetSubpath", Evaluate_Type,   MethodListArgs_383_1, MethodList_Nil -> MethodList_383_1)
    MakeCustomInvokeMethodArgs3(In_Mode, 0, In_Mode, 1, In_Mode, 2 -> MethodListArgs_383_0)
    MakeCustomInvokeMethodList("MCCanvasPathGetSubpaths", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 2, Signature_Nil))), MethodList_383_1 -> MethodList_383_0)
    MakeCustomInvokeList("PathPropertySubpath", "com.livecode.canvas", MethodList_383_0, List_Nil -> List_381_1)
    DefineCustomInvokeList(381, List_381_1)
    InitializeCustomInvokeLists_330

'action' InitializeCustomInvokeLists_330
  'rule' InitializeCustomInvokeLists_330
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodList("MCCanvasPathMakeWithSegmentWithRadiiAsList", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, invokesignature(In_Mode, 4, Signature_Nil)))), MethodList_Nil -> MethodList_384_1)
    MakeCustomInvokeMethodList("MCCanvasPathMakeWithSegmentWithRadius", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 3, invokesignature(In_Mode, 4, Signature_Nil)))), MethodList_384_1 -> MethodList_384_0)
    MakeCustomInvokeList("PathMakeWithSegment", "com.livecode.canvas", MethodList_384_0, List_Nil -> List_383_1)
    DefineCustomInvokeList(383, List_383_1)
    MakeCustomInvokeMethodList("MCCanvasPathMakeWithSectorWithRadiiAsList", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, invokesignature(In_Mode, 4, Signature_Nil)))), MethodList_Nil -> MethodList_385_1)
    MakeCustomInvokeMethodList("MCCanvasPathMakeWithSectorWithRadius", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 3, invokesignature(In_Mode, 4, Signature_Nil)))), MethodList_385_1 -> MethodList_385_0)
    MakeCustomInvokeList("PathMakeWithSector", "com.livecode.canvas", MethodList_385_0, List_Nil -> List_385_1)
    DefineCustomInvokeList(385, List_385_1)
    MakeCustomInvokeMethodList("MCCanvasPathMakeWithArcWithRadiiAsList", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 2, invokesignature(In_Mode, 3, invokesignature(In_Mode, 4, Signature_Nil)))), MethodList_Nil -> MethodList_386_1)
    MakeCustomInvokeMethodList("MCCanvasPathMakeWithArcWithRadius", Evaluate_Type, invokesignature(In_Mode, 0, invokesignature(In_Mode, 1, invokesignature(In_Mode, 3, invokesignature(In_Mode, 4, Signature_Nil)))), MethodList_386_1 -> MethodList_386_0)
    MakeCustomInvokeList("PathMakeWithArc", "com.livecode.canvas", MethodList_386_0, List_Nil -> List_387_1)
    DefineCustomInvokeList(387, List_387_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_387_0)
    MakeCustomInvokeMethodList("MCCanvasPathMakeWithPoints", Evaluate_Type,   MethodListArgs_387_0, MethodList_Nil -> MethodList_387_0)
    MakeCustomInvokeList("PathMakeWithPoints", "com.livecode.canvas", MethodList_387_0, List_Nil -> List_389_1)
    DefineCustomInvokeList(389, List_389_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_388_0)
    MakeCustomInvokeMethodList("MCCanvasPathMakeWithLine", Evaluate_Type,   MethodListArgs_388_0, MethodList_Nil -> MethodList_388_0)
    MakeCustomInvokeList("PathMakeWithLine", "com.livecode.canvas", MethodList_388_0, List_Nil -> List_391_1)
    DefineCustomInvokeList(391, List_391_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_389_0)
    MakeCustomInvokeMethodList("MCCanvasPathMakeWithEllipseWithRadiiAsList", Evaluate_Type,   MethodListArgs_389_0, MethodList_Nil -> MethodList_389_0)
    MakeCustomInvokeList("PathMakeWithEllipse", "com.livecode.canvas", MethodList_389_0, List_Nil -> List_392_1)
    DefineCustomInvokeList(392, List_392_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_390_0)
    MakeCustomInvokeMethodList("MCCanvasPathMakeWithCircle", Evaluate_Type,   MethodListArgs_390_0, MethodList_Nil -> MethodList_390_0)
    MakeCustomInvokeList("PathMakeWithCircle", "com.livecode.canvas", MethodList_390_0, List_Nil -> List_393_1)
    DefineCustomInvokeList(393, List_393_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_391_0)
    MakeCustomInvokeMethodList("MCCanvasPathMakeWithRectangle", Evaluate_Type,   MethodListArgs_391_0, MethodList_Nil -> MethodList_391_0)
    MakeCustomInvokeList("PathMakeWithRectangle", "com.livecode.canvas", MethodList_391_0, List_Nil -> List_394_1)
    DefineCustomInvokeList(394, List_394_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_392_0)
    MakeCustomInvokeMethodList("MCCanvasPathMakeWithRoundedRectangleWithRadiiAsList", Evaluate_Type,   MethodListArgs_392_0, MethodList_Nil -> MethodList_392_0)
    MakeCustomInvokeList("PathMakeWithRoundedRectangleWithRadii", "com.livecode.canvas", MethodList_392_0, List_Nil -> List_395_1)
    DefineCustomInvokeList(395, List_395_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_393_0)
    MakeCustomInvokeMethodList("MCCanvasPathMakeWithRoundedRectangle", Evaluate_Type,   MethodListArgs_393_0, MethodList_Nil -> MethodList_393_0)
    MakeCustomInvokeList("PathMakeWithRoundedRectangleWithRadius", "com.livecode.canvas", MethodList_393_0, List_Nil -> List_396_1)
    DefineCustomInvokeList(396, List_396_1)
    InitializeCustomInvokeLists_340

'action' InitializeCustomInvokeLists_340
  'rule' InitializeCustomInvokeLists_340
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_394_0)
    MakeCustomInvokeMethodList("MCCanvasPathMakeWithInstructionsAsString", Evaluate_Type,   MethodListArgs_394_0, MethodList_Nil -> MethodList_394_0)
    MakeCustomInvokeList("PathMake", "com.livecode.canvas", MethodList_394_0, List_Nil -> List_397_1)
    DefineCustomInvokeList(397, List_397_1)
    MakeCustomInvokeMethodList("MCCanvasPathMakeEmpty", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_395_0)
    MakeCustomInvokeList("PathMakeEmpty", "com.livecode.canvas", MethodList_395_0, List_Nil -> List_398_1)
    DefineCustomInvokeList(398, List_398_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_396_0)
    MakeCustomInvokeMethodList("MCCanvasImageGetPixels", Evaluate_Type,   MethodListArgs_396_0, MethodList_Nil -> MethodList_396_0)
    MakeCustomInvokeList("ImagePropertyPixels", "com.livecode.canvas", MethodList_396_0, List_Nil -> List_399_1)
    DefineCustomInvokeList(399, List_399_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_397_0)
    MakeCustomInvokeMethodList("MCCanvasImageGetDensity", Evaluate_Type,   MethodListArgs_397_0, MethodList_Nil -> MethodList_397_0)
    MakeCustomInvokeList("ImageDensityProperty", "com.livecode.canvas", MethodList_397_0, List_Nil -> List_400_1)
    DefineCustomInvokeList(400, List_400_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_398_0)
    MakeCustomInvokeMethodList("MCCanvasImageGetMetadata", Evaluate_Type,   MethodListArgs_398_0, MethodList_Nil -> MethodList_398_0)
    MakeCustomInvokeList("ImageMetadataProperty", "com.livecode.canvas", MethodList_398_0, List_Nil -> List_401_1)
    DefineCustomInvokeList(401, List_401_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_399_0)
    MakeCustomInvokeMethodList("MCCanvasImageMakeWithPixelsWithSizeAsList", Evaluate_Type,   MethodListArgs_399_0, MethodList_Nil -> MethodList_399_0)
    MakeCustomInvokeList("ImageMakeWithPixels", "com.livecode.canvas", MethodList_399_0, List_Nil -> List_402_1)
    DefineCustomInvokeList(402, List_402_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_400_0)
    MakeCustomInvokeMethodList("MCCanvasImageMakeWithData", Evaluate_Type,   MethodListArgs_400_0, MethodList_Nil -> MethodList_400_0)
    MakeCustomInvokeList("ImageMakeFromData", "com.livecode.canvas", MethodList_400_0, List_Nil -> List_403_1)
    DefineCustomInvokeList(403, List_403_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_401_0)
    MakeCustomInvokeMethodList("MCCanvasImageMakeWithResourceFile", Evaluate_Type,   MethodListArgs_401_0, MethodList_Nil -> MethodList_401_0)
    MakeCustomInvokeList("ImageMakeFromResourceFile", "com.livecode.canvas", MethodList_401_0, List_Nil -> List_404_1)
    DefineCustomInvokeList(404, List_404_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_402_0)
    MakeCustomInvokeMethodList("MCCanvasImageMakeWithPath", Evaluate_Type,   MethodListArgs_402_0, MethodList_Nil -> MethodList_402_0)
    MakeCustomInvokeList("ImageMakeFromFile", "com.livecode.canvas", MethodList_402_0, List_Nil -> List_405_1)
    DefineCustomInvokeList(405, List_405_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_403_0)
    MakeCustomInvokeMethodList("MCArithmeticExecAddNumberToNumber", Execute_Type,   MethodListArgs_403_0, MethodList_Nil -> MethodList_403_0)
    MakeCustomInvokeList("AddNumberTo", "com.livecode.arithmetic", MethodList_403_0, List_Nil -> List_406_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_404_0)
    MakeCustomInvokeMethodList("MCCanvasAddPath", Execute_Type,   MethodListArgs_404_0, MethodList_Nil -> MethodList_404_0)
    MakeCustomInvokeList("CanvasOperationAddPath", "com.livecode.canvas", MethodList_404_0, List_406_1 -> List_406_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_405_0)
    MakeCustomInvokeMethodList("MCCanvasPathAddPath", Execute_Type,   MethodListArgs_405_0, MethodList_Nil -> MethodList_405_0)
    MakeCustomInvokeList("PathOperationAddPath", "com.livecode.canvas", MethodList_405_0, List_406_2 -> List_406_3)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, InOut_Mode, 1 -> MethodListArgs_406_0)
    MakeCustomInvokeMethodList("MCCanvasGradientAddStop", Execute_Type,   MethodListArgs_406_0, MethodList_Nil -> MethodList_406_0)
    MakeCustomInvokeList("GradientOperationAddStop", "com.livecode.canvas", MethodList_406_0, List_406_3 -> List_406_4)
    DefineCustomInvokeList(406, List_406_4)
    InitializeCustomInvokeLists_350

'action' InitializeCustomInvokeLists_350
  'rule' InitializeCustomInvokeLists_350
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_407_1)
    MakeCustomInvokeMethodList("MCCanvasGradientSetVia", Assign_Type,   MethodListArgs_407_1, MethodList_Nil -> MethodList_407_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_407_0)
    MakeCustomInvokeMethodList("MCCanvasGradientGetVia", Evaluate_Type,   MethodListArgs_407_0, MethodList_407_1 -> MethodList_407_0)
    MakeCustomInvokeList("GradientPropertyVia", "com.livecode.canvas", MethodList_407_0, List_Nil -> List_407_1)
    DefineCustomInvokeList(407, List_407_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_408_1)
    MakeCustomInvokeMethodList("MCCanvasGradientSetTo", Assign_Type,   MethodListArgs_408_1, MethodList_Nil -> MethodList_408_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_408_0)
    MakeCustomInvokeMethodList("MCCanvasGradientGetTo", Evaluate_Type,   MethodListArgs_408_0, MethodList_408_1 -> MethodList_408_0)
    MakeCustomInvokeList("GradientPropertyTo", "com.livecode.canvas", MethodList_408_0, List_Nil -> List_408_1)
    DefineCustomInvokeList(408, List_408_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_409_1)
    MakeCustomInvokeMethodList("MCCanvasGradientSetFrom", Assign_Type,   MethodListArgs_409_1, MethodList_Nil -> MethodList_409_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_409_0)
    MakeCustomInvokeMethodList("MCCanvasGradientGetFrom", Evaluate_Type,   MethodListArgs_409_0, MethodList_409_1 -> MethodList_409_0)
    MakeCustomInvokeList("GradientPropertyFrom", "com.livecode.canvas", MethodList_409_0, List_Nil -> List_409_1)
    DefineCustomInvokeList(409, List_409_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_410_1)
    MakeCustomInvokeMethodList("MCCanvasGradientSetMirror", Assign_Type,   MethodListArgs_410_1, MethodList_Nil -> MethodList_410_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_410_0)
    MakeCustomInvokeMethodList("MCCanvasGradientGetMirror", Evaluate_Type,   MethodListArgs_410_0, MethodList_410_1 -> MethodList_410_0)
    MakeCustomInvokeList("GradientPropertyMirror", "com.livecode.canvas", MethodList_410_0, List_Nil -> List_410_1)
    DefineCustomInvokeList(410, List_410_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_411_1)
    MakeCustomInvokeMethodList("MCCanvasGradientSetWrap", Assign_Type,   MethodListArgs_411_1, MethodList_Nil -> MethodList_411_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_411_0)
    MakeCustomInvokeMethodList("MCCanvasGradientGetWrap", Evaluate_Type,   MethodListArgs_411_0, MethodList_411_1 -> MethodList_411_0)
    MakeCustomInvokeList("GradientPropertyWrap", "com.livecode.canvas", MethodList_411_0, List_Nil -> List_411_1)
    DefineCustomInvokeList(411, List_411_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_412_1)
    MakeCustomInvokeMethodList("MCCanvasGradientSetRepeat", Assign_Type,   MethodListArgs_412_1, MethodList_Nil -> MethodList_412_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_412_0)
    MakeCustomInvokeMethodList("MCCanvasGradientGetRepeat", Evaluate_Type,   MethodListArgs_412_0, MethodList_412_1 -> MethodList_412_0)
    MakeCustomInvokeList("GradientPropertyRepeat", "com.livecode.canvas", MethodList_412_0, List_Nil -> List_412_1)
    DefineCustomInvokeList(412, List_412_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_413_0)
    MakeCustomInvokeMethodList("MCCanvasEffectGetTypeAsString", Evaluate_Type,   MethodListArgs_413_0, MethodList_Nil -> MethodList_413_0)
    MakeCustomInvokeList("EffectPropertyType", "com.livecode.canvas", MethodList_413_0, List_Nil -> List_413_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_414_1)
    MakeCustomInvokeMethodList("MCCanvasGradientSetTypeAsString", Assign_Type,   MethodListArgs_414_1, MethodList_Nil -> MethodList_414_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_414_0)
    MakeCustomInvokeMethodList("MCCanvasGradientGetTypeAsString", Evaluate_Type,   MethodListArgs_414_0, MethodList_414_1 -> MethodList_414_0)
    MakeCustomInvokeList("GradientPropertyType", "com.livecode.canvas", MethodList_414_0, List_413_1 -> List_413_2)
    DefineCustomInvokeList(413, List_413_2)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_415_1)
    MakeCustomInvokeMethodList("MCCanvasGradientSetRamp", Assign_Type,   MethodListArgs_415_1, MethodList_Nil -> MethodList_415_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_415_0)
    MakeCustomInvokeMethodList("MCCanvasGradientGetRamp", Evaluate_Type,   MethodListArgs_415_0, MethodList_415_1 -> MethodList_415_0)
    MakeCustomInvokeList("GradientPropertyRamp", "com.livecode.canvas", MethodList_415_0, List_Nil -> List_414_1)
    DefineCustomInvokeList(414, List_414_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_416_1)
    MakeCustomInvokeMethodList("MCCanvasGradientStopSetOffset", Assign_Type,   MethodListArgs_416_1, MethodList_Nil -> MethodList_416_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_416_0)
    MakeCustomInvokeMethodList("MCCanvasGradientStopGetOffset", Evaluate_Type,   MethodListArgs_416_0, MethodList_416_1 -> MethodList_416_0)
    MakeCustomInvokeList("GradientStopPropertyOffset", "com.livecode.canvas", MethodList_416_0, List_Nil -> List_415_1)
    DefineCustomInvokeList(415, List_415_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_417_0)
    MakeCustomInvokeMethodList("MCCanvasGradientMakeWithRamp", Evaluate_Type,   MethodListArgs_417_0, MethodList_Nil -> MethodList_417_0)
    MakeCustomInvokeList("GradientMakeWithRamp", "com.livecode.canvas", MethodList_417_0, List_Nil -> List_416_1)
    DefineCustomInvokeList(416, List_416_1)
    InitializeCustomInvokeLists_360

'action' InitializeCustomInvokeLists_360
  'rule' InitializeCustomInvokeLists_360
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_418_0)
    MakeCustomInvokeMethodList("MCCanvasGradientStopMake", Evaluate_Type,   MethodListArgs_418_0, MethodList_Nil -> MethodList_418_0)
    MakeCustomInvokeList("GradientStopMake", "com.livecode.canvas", MethodList_418_0, List_Nil -> List_417_1)
    DefineCustomInvokeList(417, List_417_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_419_0)
    MakeCustomInvokeMethodList("MCCanvasGradientEvaluateType", Evaluate_Type,   MethodListArgs_419_0, MethodList_Nil -> MethodList_419_0)
    MakeCustomInvokeList("GradientType", "com.livecode.canvas", MethodList_419_0, List_Nil -> List_418_1)
    DefineCustomInvokeList(418, List_418_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_420_0)
    MakeCustomInvokeMethodList("MCCanvasTransform", Execute_Type,   MethodListArgs_420_0, MethodList_Nil -> MethodList_420_0)
    MakeCustomInvokeList("CanvasOperationTransform", "com.livecode.canvas", MethodList_420_0, List_Nil -> List_419_1)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_421_0)
    MakeCustomInvokeMethodList("MCCanvasPathTransform", Execute_Type,   MethodListArgs_421_0, MethodList_Nil -> MethodList_421_0)
    MakeCustomInvokeList("PathOperationTransform", "com.livecode.canvas", MethodList_421_0, List_419_1 -> List_419_2)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_422_0)
    MakeCustomInvokeMethodList("MCCanvasGradientTransform", Execute_Type,   MethodListArgs_422_0, MethodList_Nil -> MethodList_422_0)
    MakeCustomInvokeList("GradientOperationTransform", "com.livecode.canvas", MethodList_422_0, List_419_2 -> List_419_3)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_423_0)
    MakeCustomInvokeMethodList("MCCanvasPatternTransform", Execute_Type,   MethodListArgs_423_0, MethodList_Nil -> MethodList_423_0)
    MakeCustomInvokeList("PatternOperationTransform", "com.livecode.canvas", MethodList_423_0, List_419_3 -> List_419_4)
    DefineCustomInvokeList(419, List_419_4)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_424_1)
    MakeCustomInvokeMethodList("MCCanvasGradientSetTransform", Assign_Type,   MethodListArgs_424_1, MethodList_Nil -> MethodList_424_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_424_0)
    MakeCustomInvokeMethodList("MCCanvasGradientGetTransform", Evaluate_Type,   MethodListArgs_424_0, MethodList_424_1 -> MethodList_424_0)
    MakeCustomInvokeList("GradientPropertyTransform", "com.livecode.canvas", MethodList_424_0, List_Nil -> List_420_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_425_1)
    MakeCustomInvokeMethodList("MCCanvasPatternSetTransform", Assign_Type,   MethodListArgs_425_1, MethodList_Nil -> MethodList_425_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_425_0)
    MakeCustomInvokeMethodList("MCCanvasPatternGetTransform", Evaluate_Type,   MethodListArgs_425_0, MethodList_425_1 -> MethodList_425_0)
    MakeCustomInvokeList("PatternPropertyTransform", "com.livecode.canvas", MethodList_425_0, List_420_1 -> List_420_2)
    DefineCustomInvokeList(420, List_420_2)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_426_1)
    MakeCustomInvokeMethodList("MCCanvasPatternSetImage", Assign_Type,   MethodListArgs_426_1, MethodList_Nil -> MethodList_426_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_426_0)
    MakeCustomInvokeMethodList("MCCanvasPatternGetImage", Evaluate_Type,   MethodListArgs_426_0, MethodList_426_1 -> MethodList_426_0)
    MakeCustomInvokeList("PatternPropertyImage", "com.livecode.canvas", MethodList_426_0, List_Nil -> List_421_1)
    DefineCustomInvokeList(421, List_421_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_427_0)
    MakeCustomInvokeMethodList("MCCanvasPatternMakeWithRotatedImage", Evaluate_Type,   MethodListArgs_427_0, MethodList_Nil -> MethodList_427_0)
    MakeCustomInvokeList("PatternMakeRotatedBy", "com.livecode.canvas", MethodList_427_0, List_Nil -> List_422_1)
    DefineCustomInvokeList(422, List_422_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_428_0)
    MakeCustomInvokeMethodList("MCCanvasPatternMakeWithImageTranslatedWithList", Evaluate_Type,   MethodListArgs_428_0, MethodList_Nil -> MethodList_428_0)
    MakeCustomInvokeList("PatternMakeTranslatedBy", "com.livecode.canvas", MethodList_428_0, List_Nil -> List_423_1)
    DefineCustomInvokeList(423, List_423_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_429_0)
    MakeCustomInvokeMethodList("MCCanvasPatternMakeWithImageScaledWithList", Evaluate_Type,   MethodListArgs_429_0, MethodList_Nil -> MethodList_429_0)
    MakeCustomInvokeList("PatternMakeScaledBy", "com.livecode.canvas", MethodList_429_0, List_Nil -> List_424_1)
    DefineCustomInvokeList(424, List_424_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_430_0)
    MakeCustomInvokeMethodList("MCCanvasPatternMakeWithTransformedImage", Evaluate_Type,   MethodListArgs_430_0, MethodList_Nil -> MethodList_430_0)
    MakeCustomInvokeList("PatternMakeTransformed", "com.livecode.canvas", MethodList_430_0, List_Nil -> List_425_1)
    DefineCustomInvokeList(425, List_425_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_431_0)
    MakeCustomInvokeMethodList("MCCanvasPatternMakeWithImage", Evaluate_Type,   MethodListArgs_431_0, MethodList_Nil -> MethodList_431_0)
    MakeCustomInvokeList("PatternMake", "com.livecode.canvas", MethodList_431_0, List_Nil -> List_426_1)
    DefineCustomInvokeList(426, List_426_1)
    InitializeCustomInvokeLists_370

'action' InitializeCustomInvokeLists_370
  'rule' InitializeCustomInvokeLists_370
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_432_1)
    MakeCustomInvokeMethodList("MCCanvasEffectSetColor", Assign_Type,   MethodListArgs_432_1, MethodList_Nil -> MethodList_432_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_432_0)
    MakeCustomInvokeMethodList("MCCanvasEffectGetColor", Evaluate_Type,   MethodListArgs_432_0, MethodList_432_1 -> MethodList_432_0)
    MakeCustomInvokeList("EffectPropertyColor", "com.livecode.canvas", MethodList_432_0, List_Nil -> List_427_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_433_1)
    MakeCustomInvokeMethodList("MCCanvasGradientStopSetColor", Assign_Type,   MethodListArgs_433_1, MethodList_Nil -> MethodList_433_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_433_0)
    MakeCustomInvokeMethodList("MCCanvasGradientStopGetColor", Evaluate_Type,   MethodListArgs_433_0, MethodList_433_1 -> MethodList_433_0)
    MakeCustomInvokeList("GradientStopPropertyColor", "com.livecode.canvas", MethodList_433_0, List_427_1 -> List_427_2)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_434_1)
    MakeCustomInvokeMethodList("MCCanvasSolidPaintSetColor", Assign_Type,   MethodListArgs_434_1, MethodList_Nil -> MethodList_434_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_434_0)
    MakeCustomInvokeMethodList("MCCanvasSolidPaintGetColor", Evaluate_Type,   MethodListArgs_434_0, MethodList_434_1 -> MethodList_434_0)
    MakeCustomInvokeList("SolidPaintPropertyColor", "com.livecode.canvas", MethodList_434_0, List_427_2 -> List_427_3)
    DefineCustomInvokeList(427, List_427_3)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_435_0)
    MakeCustomInvokeMethodList("MCCanvasSolidPaintMakeWithColor", Evaluate_Type,   MethodListArgs_435_0, MethodList_Nil -> MethodList_435_0)
    MakeCustomInvokeList("SolidPaintMake", "com.livecode.canvas", MethodList_435_0, List_Nil -> List_428_1)
    DefineCustomInvokeList(428, List_428_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_436_0)
    MakeCustomInvokeMethodList("MCArithmeticEvalNumberTimesNumber", Evaluate_Type,   MethodListArgs_436_0, MethodList_Nil -> MethodList_436_0)
    MakeCustomInvokeList("TimesOperator", "com.livecode.arithmetic", MethodList_436_0, List_Nil -> List_429_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_437_0)
    MakeCustomInvokeMethodList("MCCanvasTransformMultiply", Evaluate_Type,   MethodListArgs_437_0, MethodList_Nil -> MethodList_437_0)
    MakeCustomInvokeList("TransformOperationMultiply", "com.livecode.canvas", MethodList_437_0, List_429_1 -> List_429_2)
    DefineCustomInvokeList(429, List_429_2)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_438_0)
    MakeCustomInvokeMethodList("MCCanvasTranslateWithList", Execute_Type,   MethodListArgs_438_0, MethodList_Nil -> MethodList_438_0)
    MakeCustomInvokeList("CanvasOperationTranslate", "com.livecode.canvas", MethodList_438_0, List_Nil -> List_430_1)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_439_0)
    MakeCustomInvokeMethodList("MCCanvasPathTranslateWithList", Execute_Type,   MethodListArgs_439_0, MethodList_Nil -> MethodList_439_0)
    MakeCustomInvokeList("PathOperationTranslate", "com.livecode.canvas", MethodList_439_0, List_430_1 -> List_430_2)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_440_0)
    MakeCustomInvokeMethodList("MCCanvasGradientTranslateWithList", Execute_Type,   MethodListArgs_440_0, MethodList_Nil -> MethodList_440_0)
    MakeCustomInvokeList("GradientOperationTranslate", "com.livecode.canvas", MethodList_440_0, List_430_2 -> List_430_3)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_441_0)
    MakeCustomInvokeMethodList("MCCanvasPatternTranslateWithList", Execute_Type,   MethodListArgs_441_0, MethodList_Nil -> MethodList_441_0)
    MakeCustomInvokeList("PatternOperationTranslate", "com.livecode.canvas", MethodList_441_0, List_430_3 -> List_430_4)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_442_0)
    MakeCustomInvokeMethodList("MCCanvasTransformTranslateWithList", Execute_Type,   MethodListArgs_442_0, MethodList_Nil -> MethodList_442_0)
    MakeCustomInvokeList("TransformOperationTranslate", "com.livecode.canvas", MethodList_442_0, List_430_4 -> List_430_5)
    DefineCustomInvokeList(430, List_430_5)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_443_0)
    MakeCustomInvokeMethodList("MCCanvasRotate", Execute_Type,   MethodListArgs_443_0, MethodList_Nil -> MethodList_443_0)
    MakeCustomInvokeList("CanvasOperationRotate", "com.livecode.canvas", MethodList_443_0, List_Nil -> List_431_1)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_444_0)
    MakeCustomInvokeMethodList("MCCanvasPathRotate", Execute_Type,   MethodListArgs_444_0, MethodList_Nil -> MethodList_444_0)
    MakeCustomInvokeList("PathOperationRotate", "com.livecode.canvas", MethodList_444_0, List_431_1 -> List_431_2)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_445_0)
    MakeCustomInvokeMethodList("MCCanvasGradientRotate", Execute_Type,   MethodListArgs_445_0, MethodList_Nil -> MethodList_445_0)
    MakeCustomInvokeList("GradientOperationRotate", "com.livecode.canvas", MethodList_445_0, List_431_2 -> List_431_3)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_446_0)
    MakeCustomInvokeMethodList("MCCanvasPatternRotate", Execute_Type,   MethodListArgs_446_0, MethodList_Nil -> MethodList_446_0)
    MakeCustomInvokeList("PatternOperationRotate", "com.livecode.canvas", MethodList_446_0, List_431_3 -> List_431_4)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_447_0)
    MakeCustomInvokeMethodList("MCCanvasTransformRotate", Execute_Type,   MethodListArgs_447_0, MethodList_Nil -> MethodList_447_0)
    MakeCustomInvokeList("TransformOperationRotate", "com.livecode.canvas", MethodList_447_0, List_431_4 -> List_431_5)
    DefineCustomInvokeList(431, List_431_5)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_448_0)
    MakeCustomInvokeMethodList("MCCanvasTransformSkewWithList", Execute_Type,   MethodListArgs_448_0, MethodList_Nil -> MethodList_448_0)
    MakeCustomInvokeList("TransformOperationSkew", "com.livecode.canvas", MethodList_448_0, List_Nil -> List_432_1)
    DefineCustomInvokeList(432, List_432_1)
    MakeCustomInvokeMethodArgs2(In_Mode, 0, In_Mode, 1 -> MethodListArgs_449_0)
    MakeCustomInvokeMethodList("MCCanvasScaleWithList", Execute_Type,   MethodListArgs_449_0, MethodList_Nil -> MethodList_449_0)
    MakeCustomInvokeList("CanvasOperationScale", "com.livecode.canvas", MethodList_449_0, List_Nil -> List_433_1)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_450_0)
    MakeCustomInvokeMethodList("MCCanvasPathScaleWithList", Execute_Type,   MethodListArgs_450_0, MethodList_Nil -> MethodList_450_0)
    MakeCustomInvokeList("PathOperationScale", "com.livecode.canvas", MethodList_450_0, List_433_1 -> List_433_2)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_451_0)
    MakeCustomInvokeMethodList("MCCanvasGradientScaleWithList", Execute_Type,   MethodListArgs_451_0, MethodList_Nil -> MethodList_451_0)
    MakeCustomInvokeList("GradientOperationScale", "com.livecode.canvas", MethodList_451_0, List_433_2 -> List_433_3)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_452_0)
    MakeCustomInvokeMethodList("MCCanvasPatternScaleWithList", Execute_Type,   MethodListArgs_452_0, MethodList_Nil -> MethodList_452_0)
    MakeCustomInvokeList("PatternOperationScale", "com.livecode.canvas", MethodList_452_0, List_433_3 -> List_433_4)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_453_0)
    MakeCustomInvokeMethodList("MCCanvasTransformScaleWithList", Execute_Type,   MethodListArgs_453_0, MethodList_Nil -> MethodList_453_0)
    MakeCustomInvokeList("TransformOperationScale", "com.livecode.canvas", MethodList_453_0, List_433_4 -> List_433_5)
    DefineCustomInvokeList(433, List_433_5)
    MakeCustomInvokeMethodArgs2(InOut_Mode, 0, In_Mode, 1 -> MethodListArgs_454_0)
    MakeCustomInvokeMethodList("MCCanvasTransformConcat", Execute_Type,   MethodListArgs_454_0, MethodList_Nil -> MethodList_454_0)
    MakeCustomInvokeList("TransformOperationConcat", "com.livecode.canvas", MethodList_454_0, List_Nil -> List_434_1)
    DefineCustomInvokeList(434, List_434_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_455_0)
    MakeCustomInvokeMethodList("MCCanvasTransformGetInverse", Evaluate_Type,   MethodListArgs_455_0, MethodList_Nil -> MethodList_455_0)
    MakeCustomInvokeList("TransformPropertyInverse", "com.livecode.canvas", MethodList_455_0, List_Nil -> List_435_1)
    DefineCustomInvokeList(435, List_435_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_456_1)
    MakeCustomInvokeMethodList("MCCanvasTransformSetMatrixAsList", Assign_Type,   MethodListArgs_456_1, MethodList_Nil -> MethodList_456_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_456_0)
    MakeCustomInvokeMethodList("MCCanvasTransformGetMatrixAsList", Evaluate_Type,   MethodListArgs_456_0, MethodList_456_1 -> MethodList_456_0)
    MakeCustomInvokeList("TransformPropertyMatrixAsList", "com.livecode.canvas", MethodList_456_0, List_Nil -> List_436_1)
    DefineCustomInvokeList(436, List_436_1)
    InitializeCustomInvokeLists_380

'action' InitializeCustomInvokeLists_380
  'rule' InitializeCustomInvokeLists_380
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_457_1)
    MakeCustomInvokeMethodList("MCCanvasTransformSetTranslationAsList", Assign_Type,   MethodListArgs_457_1, MethodList_Nil -> MethodList_457_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_457_0)
    MakeCustomInvokeMethodList("MCCanvasTransformGetTranslationAsList", Evaluate_Type,   MethodListArgs_457_0, MethodList_457_1 -> MethodList_457_0)
    MakeCustomInvokeList("TransformPropertyTranslation", "com.livecode.canvas", MethodList_457_0, List_Nil -> List_437_1)
    DefineCustomInvokeList(437, List_437_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_458_1)
    MakeCustomInvokeMethodList("MCCanvasTransformSetSkewAsList", Assign_Type,   MethodListArgs_458_1, MethodList_Nil -> MethodList_458_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_458_0)
    MakeCustomInvokeMethodList("MCCanvasTransformGetSkewAsList", Evaluate_Type,   MethodListArgs_458_0, MethodList_458_1 -> MethodList_458_0)
    MakeCustomInvokeList("TransformPropertySkew", "com.livecode.canvas", MethodList_458_0, List_Nil -> List_438_1)
    DefineCustomInvokeList(438, List_438_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_459_1)
    MakeCustomInvokeMethodList("MCCanvasTransformSetRotation", Assign_Type,   MethodListArgs_459_1, MethodList_Nil -> MethodList_459_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_459_0)
    MakeCustomInvokeMethodList("MCCanvasTransformGetRotation", Evaluate_Type,   MethodListArgs_459_0, MethodList_459_1 -> MethodList_459_0)
    MakeCustomInvokeList("TransformPropertyRotation", "com.livecode.canvas", MethodList_459_0, List_Nil -> List_439_1)
    DefineCustomInvokeList(439, List_439_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_460_1)
    MakeCustomInvokeMethodList("MCCanvasTransformSetScaleAsList", Assign_Type,   MethodListArgs_460_1, MethodList_Nil -> MethodList_460_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_460_0)
    MakeCustomInvokeMethodList("MCCanvasTransformGetScaleAsList", Evaluate_Type,   MethodListArgs_460_0, MethodList_460_1 -> MethodList_460_0)
    MakeCustomInvokeList("TransformPropertyScale", "com.livecode.canvas", MethodList_460_0, List_Nil -> List_440_1)
    DefineCustomInvokeList(440, List_440_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_461_0)
    MakeCustomInvokeMethodList("MCCanvasTransformMakeWithMatrixAsList", Evaluate_Type,   MethodListArgs_461_0, MethodList_Nil -> MethodList_461_0)
    MakeCustomInvokeList("TransformMakeWithMatrixAsList", "com.livecode.canvas", MethodList_461_0, List_Nil -> List_441_1)
    DefineCustomInvokeList(441, List_441_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_462_0)
    MakeCustomInvokeMethodList("MCCanvasTransformMakeTranslationWithList", Evaluate_Type,   MethodListArgs_462_0, MethodList_Nil -> MethodList_462_0)
    MakeCustomInvokeList("TransformMakeTranslation", "com.livecode.canvas", MethodList_462_0, List_Nil -> List_442_1)
    DefineCustomInvokeList(442, List_442_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_463_0)
    MakeCustomInvokeMethodList("MCCanvasTransformMakeRotation", Evaluate_Type,   MethodListArgs_463_0, MethodList_Nil -> MethodList_463_0)
    MakeCustomInvokeList("TransformMakeRotation", "com.livecode.canvas", MethodList_463_0, List_Nil -> List_443_1)
    DefineCustomInvokeList(443, List_443_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_464_0)
    MakeCustomInvokeMethodList("MCCanvasTransformMakeSkewWithList", Evaluate_Type,   MethodListArgs_464_0, MethodList_Nil -> MethodList_464_0)
    MakeCustomInvokeList("TransformMakeSkew", "com.livecode.canvas", MethodList_464_0, List_Nil -> List_444_1)
    DefineCustomInvokeList(444, List_444_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_465_0)
    MakeCustomInvokeMethodList("MCCanvasTransformMakeScaleWithList", Evaluate_Type,   MethodListArgs_465_0, MethodList_Nil -> MethodList_465_0)
    MakeCustomInvokeList("TransformMakeScale", "com.livecode.canvas", MethodList_465_0, List_Nil -> List_445_1)
    DefineCustomInvokeList(445, List_445_1)
    MakeCustomInvokeMethodList("MCCanvasTransformMakeIdentity", Evaluate_Type,  Signature_Nil, MethodList_Nil -> MethodList_466_0)
    MakeCustomInvokeList("TransformMakeIdentity", "com.livecode.canvas", MethodList_466_0, List_Nil -> List_446_1)
    DefineCustomInvokeList(446, List_446_1)
    InitializeCustomInvokeLists_390

'action' InitializeCustomInvokeLists_390
  'rule' InitializeCustomInvokeLists_390
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_467_1)
    MakeCustomInvokeMethodList("MCCanvasColorSetAlpha", Assign_Type,   MethodListArgs_467_1, MethodList_Nil -> MethodList_467_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_467_0)
    MakeCustomInvokeMethodList("MCCanvasColorGetAlpha", Evaluate_Type,   MethodListArgs_467_0, MethodList_467_1 -> MethodList_467_0)
    MakeCustomInvokeList("ColorPropertyAlpha", "com.livecode.canvas", MethodList_467_0, List_Nil -> List_447_1)
    DefineCustomInvokeList(447, List_447_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_468_1)
    MakeCustomInvokeMethodList("MCCanvasColorSetBlue", Assign_Type,   MethodListArgs_468_1, MethodList_Nil -> MethodList_468_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_468_0)
    MakeCustomInvokeMethodList("MCCanvasColorGetBlue", Evaluate_Type,   MethodListArgs_468_0, MethodList_468_1 -> MethodList_468_0)
    MakeCustomInvokeList("ColorPropertyBlue", "com.livecode.canvas", MethodList_468_0, List_Nil -> List_448_1)
    DefineCustomInvokeList(448, List_448_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_469_1)
    MakeCustomInvokeMethodList("MCCanvasColorSetGreen", Assign_Type,   MethodListArgs_469_1, MethodList_Nil -> MethodList_469_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_469_0)
    MakeCustomInvokeMethodList("MCCanvasColorGetGreen", Evaluate_Type,   MethodListArgs_469_0, MethodList_469_1 -> MethodList_469_0)
    MakeCustomInvokeList("ColorPropertyGreen", "com.livecode.canvas", MethodList_469_0, List_Nil -> List_449_1)
    DefineCustomInvokeList(449, List_449_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_470_1)
    MakeCustomInvokeMethodList("MCCanvasColorSetRed", Assign_Type,   MethodListArgs_470_1, MethodList_Nil -> MethodList_470_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_470_0)
    MakeCustomInvokeMethodList("MCCanvasColorGetRed", Evaluate_Type,   MethodListArgs_470_0, MethodList_470_1 -> MethodList_470_0)
    MakeCustomInvokeList("ColorPropertyRed", "com.livecode.canvas", MethodList_470_0, List_Nil -> List_450_1)
    DefineCustomInvokeList(450, List_450_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_471_0)
    MakeCustomInvokeMethodList("MCCanvasColorMakeWithList", Evaluate_Type,   MethodListArgs_471_0, MethodList_Nil -> MethodList_471_0)
    MakeCustomInvokeList("ColorMake", "com.livecode.canvas", MethodList_471_0, List_Nil -> List_451_1)
    DefineCustomInvokeList(451, List_451_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_472_0)
    MakeCustomInvokeMethodList("MCCanvasPointMakeWithList", Evaluate_Type,   MethodListArgs_472_0, MethodList_Nil -> MethodList_472_0)
    MakeCustomInvokeList("PointMake", "com.livecode.canvas", MethodList_472_0, List_Nil -> List_452_1)
    DefineCustomInvokeList(452, List_452_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_473_1)
    MakeCustomInvokeMethodList("MCWidgetSetHeightOfWidget", Assign_Type,   MethodListArgs_473_1, MethodList_Nil -> MethodList_473_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_473_0)
    MakeCustomInvokeMethodList("MCWidgetGetHeightOfWidget", Evaluate_Type,   MethodListArgs_473_0, MethodList_473_1 -> MethodList_473_0)
    MakeCustomInvokeList("WidgetHeightProperty", "com.livecode.widget", MethodList_473_0, List_Nil -> List_453_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_474_0)
    MakeCustomInvokeMethodList("MCCanvasImageGetHeight", Evaluate_Type,   MethodListArgs_474_0, MethodList_Nil -> MethodList_474_0)
    MakeCustomInvokeList("ImagePropertyHeight", "com.livecode.canvas", MethodList_474_0, List_453_1 -> List_453_2)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_475_1)
    MakeCustomInvokeMethodList("MCCanvasRectangleSetHeight", Assign_Type,   MethodListArgs_475_1, MethodList_Nil -> MethodList_475_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_475_0)
    MakeCustomInvokeMethodList("MCCanvasRectangleGetHeight", Evaluate_Type,   MethodListArgs_475_0, MethodList_475_1 -> MethodList_475_0)
    MakeCustomInvokeList("RectanglePropertyHeight", "com.livecode.canvas", MethodList_475_0, List_453_2 -> List_453_3)
    DefineCustomInvokeList(453, List_453_3)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_476_1)
    MakeCustomInvokeMethodList("MCWidgetSetWidthOfWidget", Assign_Type,   MethodListArgs_476_1, MethodList_Nil -> MethodList_476_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_476_0)
    MakeCustomInvokeMethodList("MCWidgetGetWidthOfWidget", Evaluate_Type,   MethodListArgs_476_0, MethodList_476_1 -> MethodList_476_0)
    MakeCustomInvokeList("WidgetWidthProperty", "com.livecode.widget", MethodList_476_0, List_Nil -> List_454_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_477_0)
    MakeCustomInvokeMethodList("MCCanvasImageGetWidth", Evaluate_Type,   MethodListArgs_477_0, MethodList_Nil -> MethodList_477_0)
    MakeCustomInvokeList("ImagePropertyWidth", "com.livecode.canvas", MethodList_477_0, List_454_1 -> List_454_2)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_478_1)
    MakeCustomInvokeMethodList("MCCanvasRectangleSetWidth", Assign_Type,   MethodListArgs_478_1, MethodList_Nil -> MethodList_478_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_478_0)
    MakeCustomInvokeMethodList("MCCanvasRectangleGetWidth", Evaluate_Type,   MethodListArgs_478_0, MethodList_478_1 -> MethodList_478_0)
    MakeCustomInvokeList("RectanglePropertyWidth", "com.livecode.canvas", MethodList_478_0, List_454_2 -> List_454_3)
    DefineCustomInvokeList(454, List_454_3)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_479_1)
    MakeCustomInvokeMethodList("MCCanvasRectangleSetBottom", Assign_Type,   MethodListArgs_479_1, MethodList_Nil -> MethodList_479_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_479_0)
    MakeCustomInvokeMethodList("MCCanvasRectangleGetBottom", Evaluate_Type,   MethodListArgs_479_0, MethodList_479_1 -> MethodList_479_0)
    MakeCustomInvokeList("RectanglePropertyBottom", "com.livecode.canvas", MethodList_479_0, List_Nil -> List_455_1)
    DefineCustomInvokeList(455, List_455_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_480_1)
    MakeCustomInvokeMethodList("MCCanvasRectangleSetRight", Assign_Type,   MethodListArgs_480_1, MethodList_Nil -> MethodList_480_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_480_0)
    MakeCustomInvokeMethodList("MCCanvasRectangleGetRight", Evaluate_Type,   MethodListArgs_480_0, MethodList_480_1 -> MethodList_480_0)
    MakeCustomInvokeList("RectanglePropertyRight", "com.livecode.canvas", MethodList_480_0, List_Nil -> List_456_1)
    DefineCustomInvokeList(456, List_456_1)
    InitializeCustomInvokeLists_400

'action' InitializeCustomInvokeLists_400
  'rule' InitializeCustomInvokeLists_400
    where(INVOKELIST'nil -> List_Nil)
    where(INVOKEMETHODLIST'nil -> MethodList_Nil)
    where(INVOKESIGNATURE'nil -> Signature_Nil)
    where(MODE'in -> In_Mode)
    where(MODE'out -> Out_Mode)
    where(MODE'inout -> InOut_Mode)
    where(INVOKEMETHODTYPE'execute -> Execute_Type)
    where(INVOKEMETHODTYPE'evaluate -> Evaluate_Type)
    where(INVOKEMETHODTYPE'assign -> Assign_Type)
    where(INVOKEMETHODTYPE'iterate -> Iterate_Type)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_481_1)
    MakeCustomInvokeMethodList("MCCanvasPointSetY", Assign_Type,   MethodListArgs_481_1, MethodList_Nil -> MethodList_481_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_481_0)
    MakeCustomInvokeMethodList("MCCanvasPointGetY", Evaluate_Type,   MethodListArgs_481_0, MethodList_481_1 -> MethodList_481_0)
    MakeCustomInvokeList("PointPropertyY", "com.livecode.canvas", MethodList_481_0, List_Nil -> List_457_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_482_1)
    MakeCustomInvokeMethodList("MCCanvasRectangleSetTop", Assign_Type,   MethodListArgs_482_1, MethodList_Nil -> MethodList_482_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_482_0)
    MakeCustomInvokeMethodList("MCCanvasRectangleGetTop", Evaluate_Type,   MethodListArgs_482_0, MethodList_482_1 -> MethodList_482_0)
    MakeCustomInvokeList("RectanglePropertyY", "com.livecode.canvas", MethodList_482_0, List_457_1 -> List_457_2)
    DefineCustomInvokeList(457, List_457_2)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_483_1)
    MakeCustomInvokeMethodList("MCCanvasRectangleSetTop", Assign_Type,   MethodListArgs_483_1, MethodList_Nil -> MethodList_483_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_483_0)
    MakeCustomInvokeMethodList("MCCanvasRectangleGetTop", Evaluate_Type,   MethodListArgs_483_0, MethodList_483_1 -> MethodList_483_0)
    MakeCustomInvokeList("RectanglePropertyTop", "com.livecode.canvas", MethodList_483_0, List_Nil -> List_458_1)
    DefineCustomInvokeList(458, List_458_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_484_1)
    MakeCustomInvokeMethodList("MCCanvasPointSetX", Assign_Type,   MethodListArgs_484_1, MethodList_Nil -> MethodList_484_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_484_0)
    MakeCustomInvokeMethodList("MCCanvasPointGetX", Evaluate_Type,   MethodListArgs_484_0, MethodList_484_1 -> MethodList_484_0)
    MakeCustomInvokeList("PointPropertyX", "com.livecode.canvas", MethodList_484_0, List_Nil -> List_459_1)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_485_1)
    MakeCustomInvokeMethodList("MCCanvasRectangleSetLeft", Assign_Type,   MethodListArgs_485_1, MethodList_Nil -> MethodList_485_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_485_0)
    MakeCustomInvokeMethodList("MCCanvasRectangleGetLeft", Evaluate_Type,   MethodListArgs_485_0, MethodList_485_1 -> MethodList_485_0)
    MakeCustomInvokeList("RectanglePropertyX", "com.livecode.canvas", MethodList_485_0, List_459_1 -> List_459_2)
    DefineCustomInvokeList(459, List_459_2)
    MakeCustomInvokeMethodArgs1(InOut_Mode, 0 -> MethodListArgs_486_1)
    MakeCustomInvokeMethodList("MCCanvasRectangleSetLeft", Assign_Type,   MethodListArgs_486_1, MethodList_Nil -> MethodList_486_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_486_0)
    MakeCustomInvokeMethodList("MCCanvasRectangleGetLeft", Evaluate_Type,   MethodListArgs_486_0, MethodList_486_1 -> MethodList_486_0)
    MakeCustomInvokeList("RectanglePropertyLeft", "com.livecode.canvas", MethodList_486_0, List_Nil -> List_460_1)
    DefineCustomInvokeList(460, List_460_1)
    MakeCustomInvokeMethodArgs1(In_Mode, 0 -> MethodListArgs_487_0)
    MakeCustomInvokeMethodList("MCCanvasRectangleMakeWithList", Evaluate_Type,   MethodListArgs_487_0, MethodList_Nil -> MethodList_487_0)
    MakeCustomInvokeList("RectangleMake", "com.livecode.canvas", MethodList_487_0, List_Nil -> List_461_1)
    DefineCustomInvokeList(461, List_461_1)
'nonterm' CustomKeywords(-> STRING)
  'rule' CustomKeywords(-> String):
    "jump"
    where("jump" -> String)
  'rule' CustomKeywords(-> String):
    "jump_if_false"
    where("jump_if_false" -> String)
  'rule' CustomKeywords(-> String):
    "jump_if_true"
    where("jump_if_true" -> String)
  'rule' CustomKeywords(-> String):
    "assign_constant"
    where("assign_constant" -> String)
  'rule' CustomKeywords(-> String):
    "assign"
    where("assign" -> String)
  'rule' CustomKeywords(-> String):
    "return"
    where("return" -> String)
  'rule' CustomKeywords(-> String):
    "invoke"
    where("invoke" -> String)
  'rule' CustomKeywords(-> String):
    "invoke_indirect"
    where("invoke_indirect" -> String)
  'rule' CustomKeywords(-> String):
    "fetch"
    where("fetch" -> String)
  'rule' CustomKeywords(-> String):
    "store"
    where("store" -> String)
  'rule' CustomKeywords(-> String):
    "assign_list"
    where("assign_list" -> String)
  'rule' CustomKeywords(-> String):
    "assign_array"
    where("assign_array" -> String)
  'rule' CustomKeywords(-> String):
    "reset"
    where("reset" -> String)
