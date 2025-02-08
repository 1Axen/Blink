--!strict
--!native
--!optimize 2

local Lexer = require("./Lexer")
local Table = require("./Modules/Table")
local Error = require("./Modules/Error")
local PathParser = require("./Modules/Path")

local Settings = require("./Settings")

---- Globals ----

type NumberRange = {Min: number, Max: number}
local NumberRange = {
    new = function(Min: number, Max: number?): NumberRange
        return {
            Min = Min,
            Max = Max or Min
        }
    end
}

---- Types ----

type Token = Lexer.Token

type Type = "Type" | "Event" | "Scope"
type Node<Type, Body, Tokens> = {
    Type: Type,
    Name: string,
    Value: Body,
    Tokens: Tokens
}

type Generics = {
    Span: Error.Span,
    List: {string},
    Keys: {[string]: {Generic}},
}

type Reference = {
    Name: Token,
    To: TypeNode
}

export type Scope = {
    Name: Token,
    Parent: Scope?,
    Symbols: {
        Types: {[string]: Reference},
        Scopes: {[string]: Scope},
    },
}

type EventOption = {
    Key: string, 
    Type: Lexer.Types, 
    Values: {any},
    Optional: true?,
}

type Attributes = {
    Scope: Scope?,
    Range: NumberRange?,
    Export: boolean?,
    Generics: Generics?,
    Parameters: {TypeNode}?,
    Components: {string}?
}

type AttributesTokens = {
    Range: Token?,
}

export type Options = {
    Casing: string?,
    UseColon: boolean?,
    UsePolling: boolean?,
    Typescript: boolean?,
    TypesOutput: string?,
    ClientOutput: string?,
    ServerOutput: string?,
    FutureLibrary: string?,
    PromiseLibrary: string?,
    WriteValidations: boolean?,
    ManualReplication: boolean?,
}

export type Body = Node<"Body", {
    Options: Options,
    Symbols: {[string]: true},
    Declarations: {Declaration}
}, {}>

type Declarations = "Map" | "Set" | "Enum" | "TagEnum" | "Tuple" | "Struct" | "Primitive" | "Generic" | "Array" | "Event" | "Function" | "Scope" | "Optional"
export type TypeNode = 
    | Map 
    | Set 
    | Enum 
    | TagEnum 
    | Tuple 
    | Struct 
    | Primitive 
    | Generic 
    | Array
    | Optional

export type Declaration = Node<Declarations, {
    [any]: any
}, {
    [any]: any
}>

export type Array = Node<"Array", {
    Of: TypeNode
} & Attributes, AttributesTokens>

export type Optional = Node<"Optional", {
    Of: TypeNode
} & Attributes, AttributesTokens>

export type Set = Node<"Set", {
    Values: {string}
} & Attributes, AttributesTokens>

export type Map = Node<"Map", {
    Values: {TypeNode}
} & Attributes, AttributesTokens>

export type Enum = Node<"Enum", {
    Values: {string}
} & Attributes, AttributesTokens>

export type TagEnum = Node<"TagEnum", {
    Tag: string,
    Values: {Struct}
} & Attributes, AttributesTokens>

export type Struct = Node<"Struct", {
    Values: {TypeNode}
} & Attributes, AttributesTokens>

export type Primitive = Node<"Primitive", {
    Class: string?,
    Primitive: Settings.Primitive,
} & Attributes, {
    Primitive: Token,
} & AttributesTokens>

export type Generic = Node<"Generic", {
    Generic: string,
} & Attributes, AttributesTokens>

export type Tuple = Node<"Tuple", {
    Values: {TypeNode}
} & Attributes, AttributesTokens>

export type Event = Node<"Event", {
    From: "Client" | "Server",
    Type: "Reliable" | "Unreliable",
    Call: "SingleSync" | "SingleAsync" | "ManySync" | "ManyAsync",
    Poll: boolean?,
    Data: (TypeNode | Tuple)? 
}, {}>

export type Function = Node<"Function", {
    Yield: "Future" | "Promise" | "Coroutine",
    Data: (TypeNode | Tuple)?,
    Return: (TypeNode | Tuple)?
}, {}>

export type ScopeNode = Node<"Scope", {
    Scope: Scope,
    Values: {Declaration}
}, {}> 

---- Settings ----

local OPTIONS: {[string]: Lexer.Types} = {
    Casing = "Identifier",
    UseColon = "Boolean",
    UsePolling = "Boolean",
    Typescript = "Boolean",
    TypesOutput = "String",
    ClientOutput = "String",
    ServerOutput = "String",
    FutureLibrary = "String",
    PromiseLibrary = "String",
    WriteValidations = "Boolean",
    ManualReplication = "Boolean",
}

local EVENT: {EventOption} = {
    {Key = "From", Type = "Identifier", Values = {"Client", "Server"}},
    {Key = "Type", Type = "Identifier", Values = {"Reliable", "Unreliable"}},
    {Key = "Call", Type = "Identifier", Values = {"SingleSync", "SingleAsync", "ManySync", "ManyAsync"}},
    {Key = "Poll", Type = "Boolean", Values = {true, false}, Optional = true},
    {Key = "Data", Type = "Identifier", Values = {}, Optional = true},
}

local FUNCTION: {EventOption} = {
    {Key = "Yield", Type = "Identifier", Values = {"Future", "Promise", "Coroutine"}},
    {Key = "Data", Type = "Identifier", Values = {}, Optional = true},
    {Key = "Return", Type = "Identifier", Values = {}, Optional = true}
}

type Bucket = "Types" | "Scopes"

local BUCKETS: {[string]: Bucket} = {
    Type = "Types",
    Event = "Scopes",
    Function = "Scopes",
    Scope = "Scopes"
}

type Keyword = {
    Class: string,
    Type: Declarations,
    Generics: boolean,
    Exportable: boolean,
}

local KEYWORDS: {[string]: Keyword} = {
    map = {
        Type = "Map",
        Class = "Type",
        Generics = true,
        Exportable = true,
    },
    set = {
        Type = "Set",
        Class = "Type",
        Generics = true,
        Exportable = true,
    },
    enum = {
        Type = "Enum",
        Class = "Type",
        Generics = true,
        Exportable = true,
    },
    type = {
        Type = "Primitive",
        Class = "Type",
        Generics = false,
        Exportable = true,
    },
    struct = {
        Type = "Struct",
        Class = "Type",
        Generics = true,
        Exportable = true,
    },
    event = {
        Type = "Event",
        Class = "Event",
        Generics = false,
        Exportable = false,
    },
    ["function"] = {
        Type = "Function",
        Class = "Function",
        Generics = false,
        Exportable = false,
    },
    scope = {
        Type = "Scope",
        Class = "Scope",
        Generics = false,
        Exportable = false,
    },
}

local GENERICS_TYPES = {
    Map = true,
    Struct = true,
    TagEnum = true
}

local RESERVED = {
    StepReplication = true
}

local PRIMITIVES = Settings.Primtives
local ARRAY_BOUNDS = NumberRange.new(0, (PRIMITIVES.u16.Bounds :: NumberRange).Max)
local UINT_BOUNDS = (PRIMITIVES.u32.Bounds :: NumberRange)
local DOUBLE_BOUNDS = (PRIMITIVES.f64.Bounds :: NumberRange)

---- Variables -----

local TotalOptions = 0
for _ in OPTIONS do
    TotalOptions += 1
end

---- Main ----

local Parser = {}
Parser.__index = Parser

export type Parser = typeof(setmetatable({} :: {
    Source: string,

    File: string?,
    Directory: string,

    Lexer: Lexer.Lexer,
    LookAhead: Token?,

    Scope: Scope,
    Symbols: {[string]: true},
    Generics: Generics?,
}, Parser))

function Parser.new(Directory: string?, File: string?): Parser
    return setmetatable({
        Source = "",
        File = File,
        Directory = Directory or "./",

        Lexer = Lexer.new("Parsing"),
        Symbols = {},
        Scope = nil :: any,
    }, Parser)
end

---- Utility Functions ----

local function IsInteger(Number: number): boolean
    return (Number // 1) == Number
end

local function GetFileSource(Path: string, Directory: string): (string?, string?)
    local IsROBLOX = (task ~= nil)
    if IsROBLOX then
        local Parent = game:GetService("ServerStorage")["BLINK_CONFIGURATION_FILES"]
        local Indices = string.split(Path, ".")
        for _, Index in Indices do
            if not Parent then
                break
            end

            Parent = Parent:FindFirstChild(Index)
        end

        return (Parent ~= nil and Parent:IsA("StringValue")) and Parent.Value or nil, ""
    end

    local fs = require("@lune/fs")
    local GetDefinitionFilePath = require("./CLI/Utility/GetDefinitionFilePath.luau")

    Path = `{Directory}{Path}`
    Path = GetDefinitionFilePath(Path)

    if not fs.isFile(Path) then
        return
    end

    local FileDirectory = PathParser.Directory(Path) or "./"
    return fs.readFile(Path), FileDirectory
end

local function IsDeclarationTypeSimiliar(A: Declarations, B: Declarations): boolean
    if A == B then
        return true
    end

    if A == "Enum" or B == "Enum" then
        return (A == "TagEnum" and B == "Enum") 
            or (A == "Enum" and B == "TagEnum")
    end

    return false
end

---- Lexer Functions -----

function Parser.Peek(self: Parser): Token
    local Token = self.LookAhead
    if not Token then
        error(Error.new(Error.ParserUnexpectedEndOfFile, self.Source, "Unexpected end of file", self.File)
            :Primary({Start = #self.Source, End = #self.Source}, "File ends here")
        :Emit())
    end

    return Token
end

function Parser.Consume(self: Parser, Type: Lexer.Types): Token
    local Token = self.LookAhead
    if not Token then
        Error.new(Error.ParserUnexpectedEndOfFile, self.Source, "Unexpected end of file", self.File)
            :Primary({Start = #self.Source, End = #self.Source}, "File ends here")
        :Emit()
        
        --> Above already errors
        error("Unexpected end of file")
    end

    if Token.Type ~= Type then
        Error.new(Error.ParserUnexpectedToken, self.Source, `Unexpected token`, self.File)
            :Primary(Token, `Expected "{Type}", found "{Token.Type}"`)
        :Emit()
    end

    --> Advance tokenizer
    self.LookAhead = self.Lexer:GetNextToken()

    return Token
end

function Parser.TryConsume(self: Parser, Type: Lexer.Types): Token?
    local Token = self.LookAhead
    if not Token then
        return
    end

    if Token.Type ~= Type then
        return
    end

    --> Advance lexer
    self.LookAhead = self.Lexer:GetNextToken()

    return Token
end

function Parser.ConsumeAny(self: Parser, ...: Lexer.Types): Token
    local Types = {...}
    for _, Type: Lexer.Types in Types do
        local Token = self:TryConsume(Type)
        if Token then
            return Token
        end
    end

    local Token = self:Peek()
    error(Error.new(Error.ParserUnexpectedToken, self.Source, `Unexpected token`, self.File)
        :Primary(Token, `Expected one of "{table.concat(Types, `", "`)}", found "{Token.Type}"`)
    :Emit())
end

function Parser.ConsumeAll(self: Parser, ...: Lexer.Types): (...Token)
    local Tokens = {}
    for _, Type: Lexer.Types in {...} do
        table.insert(Tokens, self:Consume(Type))
    end

    return table.unpack(Tokens)
end

--> Used to consume identifiers without getting "Expected Identifier, got Keyword" errors
--> Boolean flag here is code smell but this codebase is already EOL and will soonish be replaced by the rewrite

function Parser.ConsumeText(self: Parser, ConsumePrimitives: boolean?, ConsumeStrings: boolean?): Token
    --> Get text token
    local Token: Token;

    if ConsumeStrings and self:Peek().Type == "String" then
        Token = self:Consume("String")
    else
        if ConsumePrimitives then
            Token = self:ConsumeAny("As", "Import", "Boolean", "Keyword", "Identifier", "Primitive")
        else
            Token = self:ConsumeAny("As", "Import", "Boolean", "Keyword", "Identifier")
        end
    end

    --> Convert token to identifier token
    return {
        End = Token.End,
        Start = Token.Start,
        Type = "Identifier",
        Value = Token.Value
    }
end

---- Utility Parsing Functions ----

function Parser.Reference(self: Parser, Bucket: Bucket, Identifier: string): (Scope | Reference)?
    local Path = string.split(Identifier, ".")
    local Scope: Scope? = self.Scope

    local Offset = 1
    local Length = #Path
    local Result;

    while (Scope) do
        local Index = Path[Offset]
        if not Index then
            break
        end

        local Symbols = Scope.Symbols
        local Symbol = 
            if (Offset == Length) 
            then Symbols[Bucket][Index] 
            else Symbols.Scopes[Index]

        --> Nothing found in the current scope search upwards
        if Symbol == nil then
            Scope = Scope.Parent
            continue
        end

        --> We found a scope, start searching in it
        if Symbol and Offset < Length then
            Offset += 1
            Scope = Symbol :: any
            continue
        end

        --> Found the reference
        Result = Symbol
        break
    end

    return Result
end

function Parser.SetReference(self: Parser, Bucket: Bucket, Identifier: Token, Declaration: Declaration)
    local Name = Identifier.Value

    if RESERVED[Name] then
        Error.new(Error.AnalyzeReservedIdentifier, self.Source, `Reserved identifier`, self.File)
            :Primary(Identifier, `"{Name}" is reserved and cannot be used as an identifier.`)
            :Emit()
    end

    self.Symbols[Name] = true
    self.Scope.Symbols[Bucket][Name] = {
        To = Declaration,
        Name = Identifier,
    } :: Reference
end

function Parser.GetGenerics(self: Parser): Generics?
    if self.Generics then
        return self.Generics
    end

    local OpenChevrons = self:TryConsume("OpenChevrons")
    if not OpenChevrons then
        return
    end

    --> Parse generics
    local Generics: Generics = {
        Keys = {},
        List = {},
        Span = {
            Start = OpenChevrons.Start,
            End = OpenChevrons.End + 1
        },
    }

    while true do
        if self:TryConsume("CloseChevrons") then
            break
        end

        local Token = self:ConsumeText()

        Generics.Span.End = Token.End
        Generics.Keys[Token.Value] = {}
        table.insert(Generics.List, Token.Value)

        if self:Peek().Type ~= "CloseChevrons" then
            self:Consume("Comma")
        end
    end

    self.Generics = Generics
    return Generics
end

function Parser.NumberRange(self: Parser, Token: Lexer.Token, Bounds: NumberRange, Integer: boolean?): NumberRange
    local Value = Token.Value
    Value = string.sub(Value, 2, #Value - 1)

    local function ParseRange(): NumberRange
        local Single = tonumber(string.match(Value, `^(%-?%d*%.?%d+)$`))
        if Single then
            return NumberRange.new(Single)
        end

        local LowerBounds = tonumber(string.match(Value, `^(%-?%d*%.?%d+)%.%.$`))
        if LowerBounds then
            return NumberRange.new(LowerBounds, Bounds.Max)
        end

        local UpperBounds = tonumber(string.match(Value, `^%.%.(%-?%d*%.?%d+)$`))
        if UpperBounds then
            return NumberRange.new(Bounds.Min, UpperBounds)
        end

        local Lower, Upper = string.match(Value, `^(%-?%d*%.?%d+)%.%.(%-?%d*%.?%d+)$`)
        local Minimum, Maximum = tonumber(Lower), tonumber(Upper)
        if Minimum and Maximum then
            return NumberRange.new(Minimum, Maximum)
        end

        Error.new(Error.AnalyzeInvalidRange, self.Source, "Malformed range", self.File)
            :Primary(Token, "Unable to parse range")
        :Emit()

        error("never")
    end

    local Range = ParseRange()

    --> check int
    if Integer and (IsInteger(Range.Min) == false or IsInteger(Range.Max) == false) then
        Error.new(Error.AnalyzeInvalidRange, self.Source, "Expected an integer", self.File)
            :Primary(Token, "Expected an integer")
        :Emit()

        error("never")
    end

    --> check bounds
    if Range.Min < Bounds.Min or Range.Max > Bounds.Max then
        Error.new(Error.AnalyzeInvalidRange, self.Source, "Range outside bounds", self.File)
            :Primary(Token, `Expected a range within ({Bounds.Min}..{Bounds.Max})`)
        :Emit()

        error("never")
    end

    return Range
end

function Parser.Range(self: Parser, Primitive: Settings.Primitive): {Range: NumberRange, Token: Token}?
    local Token = self:TryConsume("Range")
    if Token == nil then
        return
    end

    local NumberRange = self:NumberRange(
        Token, 
        Primitive.Bounds or DOUBLE_BOUNDS, 
        Primitive.Integer
    )

    return {
        Range = NumberRange,
        Token = Token
    }
end

function Parser.Array(self: Parser): {Range: NumberRange, Token: Token}?
    local Token = self:TryConsume("Array")
    if not Token then
        return
    end

    local Value = Token.Value

    --> Empty bounds
    if Value == "[]" then
        return {
            Range = ARRAY_BOUNDS,
            Token = Token,
        }
    end
    
    --> Parse range
    local NumberRange = self:NumberRange(Token, ARRAY_BOUNDS, true)

    return {
        Range = NumberRange,
        Token = Token,
    }
end

function Parser.Components(self: Parser, Primitive: Settings.Primitive): {string}?
    local OpenChevrons = self:TryConsume("OpenChevrons")
    if not OpenChevrons then
        return
    end

    if Primitive.AllowedComponents == 0 then
        error(Error.new(Error.AnalyzeInvalidRange, self.Source, `Type doesn't accept components`, self.File)
            :Primary(OpenChevrons, `Remove component here`)
        :Emit())
    end

    local Components = {}
    local Primitives = {}

    for Index = 1, Primitive.AllowedComponents do
        table.insert(Primitives, self:Consume("Primitive"))
        if self:TryConsume("CloseChevrons") then
            break
        end

        self:Consume("Comma")
    end

    for Index, Token in Primitives do
        local Component = Token.Value
        local ComponentPrimitive = PRIMITIVES[Component]

        if not ComponentPrimitive then
            error(Error.new(Error.AnalyzeInvalidRange, self.Source, `Unknown primitive used as component`, self.File)
                :Primary(Token, `"{Component}" is invalid`)
            :Emit())
        end

        if not ComponentPrimitive.Component then
            error(Error.new(Error.AnalyzeInvalidRange, self.Source, `Invalid primitive used as component`, self.File)
                :Primary(Token, `"{Component}" cannot be used as a component`)
            :Emit())
        end

        table.insert(Components, Component)
    end

    return Components
end

function Parser.Optional(self: Parser): Token?
    return self:TryConsume("Optional")
end

--> Here's the logic:
--> When a generic is used it will reuse the same table under the hood
--> When replacing the generic the table's contents are changed to what it is being replaced with
--> Issues start to arise when you have another generic type that references a generic ex:
--> map GenericMap<K, V> = {[K]: V} 
--> struct GenericStruct<T> { Map: GenericMap<string, T> }
--> struct MergeStruct { ..GenericStruct<u8> }
--> GenericStruct is merged just fine but GenericMap loses the reference to the table for `T` somewhere along the process (likely at the deep clone stage)

function Parser.ReplaceGenerics(self: Parser, Of: TypeNode, Previous: {[string]: TypeNode}?): TypeNode
    local Clone = Table.DeepClone(Of) :: Struct
    local Generics = Clone.Value.Generics :: Generics
    local Replacements: {[string]: TypeNode} = {}

    Clone.Value.Generics = nil

    --> Parse generics input
    self:Consume("OpenChevrons")

    for Index = 1, #Generics.List do
        local Key = Generics.List[Index]
        local List = Generics.Keys[Key]

        local Token = self:Peek()
        local Declaration = self:Type(Token)
        Replacements[Key] = Declaration

        for _, Generic in List do
            local Replacement = Table.DeepClone(Declaration)

            Generic.Type = Replacement.Type
            Generic.Value = Replacement.Value
            Generic.Tokens = Replacement.Tokens
        end

        if Index < #Generics.List then
            self:Consume("Comma")
        end
    end

    self:Consume("CloseChevrons")

    --> hack to find lost references
    local function Traverse(Type: TypeNode)
        if Type.Type == "Array" or Type.Type == "Optional" then
            Traverse(Type.Value.Of)
        elseif Type.Type == "TagEnum" or Type.Type == "Struct" or Type.Type == "Map" then
            for _, Type in Type.Value.Values :: {any} do
                Traverse(Type)
            end
        elseif Type.Type == "Generic" then
            local Key = Type.Value.Generic
            local Declaration = Replacements[Key]
            if Declaration == nil then
                return
            end

            local Replacement = Table.DeepClone(Declaration)

            Type.Type = Replacement.Type
            Type.Value = Replacement.Value
            Type.Tokens = Replacement.Tokens
        end
    end

    Traverse(Clone)
    
    return Clone
end

---- Top-Level Parsing Functions ----

function Parser.Parse(self: Parser, Source: string, Scope: Scope?): Body
    --> Set state
    self.Scope = Scope or {Name = {Value = "", Start = 0, End = 0} :: any, Symbols = {Types = {}, Scopes = {}}}
    self.Source = Source
    table.clear(self.Symbols)
    
    --> Start the lexer
    self.Lexer:Initialize(Source)
    self.LookAhead = self.Lexer:GetNextToken()

    --> Parse
    local Options = self:Options()
    local Declarations = self:Declarations()

    return {
        Type = "Body",
        Name = Scope and Scope.Name.Value or "Body",
        Value = {
            Symbols = table.clone(self.Symbols),
            Options = Options,
            Declarations = Declarations
        },
        Tokens = {}
    }
end

function Parser.Import(self: Parser): ScopeNode
    self:Consume("Import")

    local Path = self:Consume("String")
    local ImportPath = Path.Value
    local ImportSource, ImportDirectory = GetFileSource(ImportPath, self.Directory)

    if not ImportSource then
        error(Error.new(Error.AnalyzeUnknownImport, self.Source, `Unknown require`, self.File)
            :Primary(Path, `Unknown require: "{ImportPath}"`)
        :Emit())
    end

    --> Import namespace
    local Name: string;
    local Token = Path

    if self:TryConsume("As") then
        --> Use user provided namespace identifier
        Token = self:ConsumeText()
        Name = Token.Value 
    elseif (task ~= nil) then
        --> ROBLOX
        local Indices = string.split(ImportPath, ".")
        Name = Indices[#Indices]
    else
        if string.sub(ImportPath, 1, 2) ~= "./" then
            ImportPath = `./{ImportPath}`
        end

        --> Use file name as namespace identifier
        local Filename = PathParser.Filename(ImportPath)
        assert(Filename, "Unable to parse file path for filename!")
        
        Name = Filename
        Token.Value = Filename
    end

    local Existing = self:Reference("Scopes", Name)
    if Existing then
        Error.new(Error.AnalyzeDuplicateDeclaration, self.Source, `Duplicate declaration: "{Name}"`, self.File)
            :Secondary(Existing.Name, "Previously declared here")
            :Primary(Token, "Duplicate declared here")
        :Emit()
    end

    --> Import
    local Parent = self.Scope
    local Scope: Scope = {
        Name = Token,
        Symbols = {
            Types = {},
            Scopes = {}
        }
    }

    local AST: Body;
    local ImportParser = Parser.new(ImportDirectory, ImportPath)
    
    local Success, ErrorText = pcall(function()
        --> Parse declarations into import scope
        AST = ImportParser:Parse(ImportSource, Scope)
    end)

    if not Success then
        error(ErrorText)
    end

    Scope.Parent = Parent
    self.Symbols[Name] = true
    Parent.Symbols.Scopes[Name] = Scope
    
    return {
        Type = "Scope",
        Name = Name,
        Value = {
            Scope = Scope,
            Values = AST.Value.Declarations
        },
        Tokens = {}
    }
end

function Parser.Options(self: Parser): Options
    local Options: Options = {}
    for Index = 1, TotalOptions do
        local Keyword = self:Peek()
        if Keyword.Value ~= "option" then
            break
        end

        self:Consume("Keyword")
        local Key = self:ConsumeAll("Identifier", "Assign")
        local Name = Key.Value
        
        local Type: Lexer.Types = OPTIONS[Name]
        if not Type then
            local Examples = ""
            for Option in OPTIONS do
                Examples ..= `{Examples ~= "" and " or " or ""}"{Option}"`
            end

            Error.new(Error.ParserUnknownOption, self.Source, `Unknown option "{Name}"`, self.File)
                :Primary(Key, `Expected one of {Examples}`)
            :Emit()
        end

        local Value = self:Consume(Type)
        Options[Name] = Value.Value
    end

    return Options
end

function Parser.Declarations(self: Parser): {Declaration}
    local Declarations = {}
    while true do
        if self:TryConsume("EndOfFile") then
            break
        end

        if self.Scope and self:TryConsume("CloseBraces") then
            break
        end

        --> Is an import?
        local LookAhead = self:Peek()
        if LookAhead.Type == "Import" then
            table.insert(Declarations, self:Import())
            continue
        end

        --> Is standalone/exported?
        local Export: Token?
        if LookAhead.Type == "Keyword" and LookAhead.Value == "export" then
            Export = self:Consume("Keyword")
        end

        local Keyword = self:Consume("Keyword")
        local Name = self:ConsumeText()
        local Declaration: Declaration;

        if Keyword.Value == "option" then
            Error.new(Error.AnalyzeOptionAfterStart, self.Source, "Option set after start of file", self.File)
                :Primary(Keyword, "Move to the start of the file")
            :Emit()
        end

        --> Prevent duplicates
        local KeywordSettings = KEYWORDS[Keyword.Value]
        local Type = KeywordSettings.Class

        local Bucket: Bucket = BUCKETS[Type]
        local Existing = self:Reference(Bucket, Name.Value)

        if Existing then
            Error.new(Error.AnalyzeDuplicateDeclaration, self.Source, `Duplicate declaration`, self.File)
                :Secondary(Existing.Name, "Previously declared here")
                :Primary(Name, "Duplicate declared here")
            :Emit()
        end

        --> Generics
        local Generics: Generics?;
        if KeywordSettings.Generics then
            Generics = self:GetGenerics()
        end

        --> Parse declaration
        if Type == "Type" then
           local Node = self:Type(Name, Keyword)
           local Value: Attributes = Node.Value
           Value.Scope = self.Scope
           Declaration = Node
        elseif Type == "Event" then
            Declaration = self:Event(Name)
        elseif Type == "Function" then
            Declaration = self:Function(Name)
        elseif Type  == "Scope" then
            Declaration = self:Namespace(Name)
        end

        --> Update declarations
        table.insert(Declarations, Declaration :: any)

        if Export then
            --> Prevent non exportable types from being exported
            if not KeywordSettings.Exportable then
                Error.new(Error.AnalyzeInvalidExport, self.Source, `Declaration of type "{Keyword.Value}" is not exportable`, self.File)
                    :Primary(Export, `Remove export here`)
                :Emit()
            --> Prevent types with generics from being exported
            elseif Generics then
                Error.new(Error.AnalyzeInvalidExport, self.Source, `Generic types can't be exported`, self.File)
                    :Primary(Export, `Remove export here`)
                :Emit()
            end

            Declaration.Value.Export = true
        end

        if Generics then
            if Declaration.Type == "Enum" then
                Error.new(Error.AnalyzeInvalidGenerics, self.Source, `Unit enums don't support generics`, self.File)
                    :Primary(Generics.Span, "Remove generics")
                :Emit()
            end

            self.Generics = nil
            Declaration.Value.Generics = Generics
        end

        if Type ~= "Scope" then
            self:SetReference(Bucket, Name, Declaration)
        end
    end

    return Declarations
end

---- Structure Parsing Functions ----

function Parser.GetOptionFromToken(self: Parser, Token: Token, Structure: {EventOption}): EventOption
    local Value = Token.Value
    for Index, Option in Structure do
        local Key = Option.Key
        if Key == Value or string.lower(Key) == Value then
            return Option
        end
    end

    local OptionsString = ""
    for Index, Option in Structure do
        OptionsString ..= `{Index ~= 1 and " or " or ""}"{Option.Key}"`
    end

    error(Error.new(Error.ParserUnknownOption, self.Source, `Unknown option "{Value}"`, self.File)
        :Primary(Token, `Expected one of {OptionsString}`)
    :Emit())
end

function Parser.Structure(self: Parser, Name: Token, Structure: {EventOption}): {[string]: any}
    local Fields: {[string]: any} = {}
    local Open, Close: Lexer.Token? = self:Consume("OpenBraces"), nil

    while true do
        Close = self:TryConsume("CloseBraces")
        if Close then
            break
        end

        local Value: any;
        local Field = self:ConsumeText()
        local Option = self:GetOptionFromToken(Field, Structure)
        self:Consume("FieldAssign")

        --> Prevent duplicate fields
        if Fields[Option.Key] then
            Error.new(Error.AnalyzeDuplicateField, self.Source, `Field "{Option.Key}" was already specified`, self.File)
                :Primary(Field, `Already specified earlier in the structure`)
            :Emit()
        end

        --> Parse non data/return field
        if Option.Key ~= "Data" and Option.Key ~= "Return" then
            local Token = self:Consume(Option.Type)
            Value = Token.Value

            if not table.find(Option.Values, Value) then
                Error.new(Error.ParserUnknownOption, self.Source, `Unknown option "{Value}"`, self.File)
                    :Primary(Token, `Expected one of "{table.concat(Option.Values, `" or "`)}"`)
                :Emit()
            end
        else
            Value = self:Type(Name, nil, true)
        end

        Fields[Option.Key] = Value  
        Close = self:TryConsume("CloseBraces")
        
        if Close then
            break
        end

        self:Consume("Comma")
    end

    --> Check if all required fields where supplied
    for _, Option in Structure do
        if Option.Optional then
            continue
        end

        if Fields[Option.Key] ~= nil then
            continue
        end

        local Span: Error.Span = {
            End = math.max((Close :: Lexer.Token).End - 2, Open.Start),
            Start = Open.Start
        }

        Error.new(Error.ParserExpectedExtraToken, self.Source, `Field "{Option.Key}" is missing`, self.File)
            :Primary(Span, `Add missing field "{Option.Key}"`)
        :Emit()
    end

    return Fields
end

function Parser.Event(self: Parser, Name: Token): Event
    local Structure = self:Structure(Name, EVENT)

    return {
        Type = "Event",
        Name = Name.Value,
        Value = {
            From = Structure.From,
            Type = Structure.Type,
            Call = Structure.Call,
            Poll = Structure.Poll,
            Data = Structure.Data
        },
        Tokens = {}
    }
end

function Parser.Function(self: Parser, Name: Token): Function
    local Structure = self:Structure(Name, FUNCTION)

    return {
        Type = "Function",
        Name = Name.Value,
        Value = {
            Yield = Structure.Yield,
            Data = Structure.Data,
            Return = Structure.Return
        },
        Tokens = {}
    }
end

function Parser.Namespace(self: Parser, Name: Token): ScopeNode
    self:Consume("OpenBraces")

    --> Open scope
    local Parent = self.Scope
    local Scope: Scope = {
        Name = Name,
        Parent = Parent,
        Symbols = {
            Types = {},
            Scopes = {}
        }
    }

    self.Scope = Scope
    self.Symbols[Name.Value] = true
    Parent.Symbols.Scopes[Name.Value] = Scope

    --> Gather declarations
    local Declarations = self:Declarations()

    --> Close scope
    self.Scope = Parent

    return {
        Type = "Scope",
        Name = Name.Value,
        Value = {
            Scope = Scope,
            Values = Declarations
        },
        Tokens = {}
    }
end

---- Type Parsing Functions ----

function Parser.Type(self: Parser, Name: Token, Keyword: Token?, IsDataField: boolean?): TypeNode
    local Declaration: TypeNode;

    --> Fast path: We know the exact type
    if Keyword then
        local Value = Keyword.Value
        if Value ~= "struct" then
            self:Consume("Assign")

            --> Handle reference declarations
            local Type = KEYWORDS[Value].Type
            local Token = self:Peek()
            
            if Token.Type == "Identifier" then
                Declaration = self:Declaration(Name)
                if not IsDeclarationTypeSimiliar(Declaration.Type, Type :: Declarations) then
                    Error.new(Error.AnalyzeReferenceInvalidType, self.Source, `Cannot cast "{Declaration.Type}" to "{Type}"`, self.File)
                        :Primary(Token, `Expected a reference to "{Type}", got "{Declaration.Type}" instead`)
                    :Emit()
                end
            end
        end

        --> Wasn't a reference declaration
        if not Declaration then
            if Value == "map" then
                Declaration = self:Map(Name)
            elseif Value == "set" then
                Declaration = self:Set(Name)
            elseif Value == "enum" then
                Declaration = self:Enum(Name)
            elseif Value == "type" then
                Declaration = self:Primitive(Name)
            elseif Value == "struct" then
                Declaration = self:Struct(Name)
            end
        end
    end

    --> Slow path: We have to figure out what we're declaring :)
    if not Keyword then
        local Peek = self:Peek()
        local Type: Lexer.Types = Peek.Type :: Lexer.Types
        
        if Type == "Keyword" then
            local Value = Peek.Value
            self:Consume("Keyword")

            if Value == "map" then
                Declaration = self:Map(Name)
            elseif Value == "set" then
                Declaration = self:Set(Name)
            elseif Value == "enum" then
                Declaration = self:Enum(Name)
            elseif Value == "struct" then
                Declaration = self:Struct(Name)
            end
        elseif Type == "Primitive" then
            Declaration = self:Primitive(Name)
        elseif Type == "Identifier" then
            Declaration = self:Declaration(Name)
        elseif Type == "OpenParentheses" and IsDataField then
            Declaration = self:Tuple(Name)
        end

        if not Declaration then
            Error.new(Error.ParserUnexpectedToken, self.Source, `Unexpected token`, self.File)
                :Primary(Peek, `Expected one of "Identifier" or "Primitive" or "Keyword", got "{Type}" instead`)
            :Emit()
        end
    end

    --> Set type attributes
    local Primitive: Settings.Primitive?;
    if Declaration.Type == "Primitive" then
        Primitive = (Declaration :: Primitive).Value.Primitive
    end

    local Value = Declaration.Value :: Attributes
    local Tokens = Declaration.Tokens :: AttributesTokens

    -- ex: vector<u8> and u8(0..00)
    if Primitive then
        Value.Components = self:Components(Primitive)
        
        local Range = self:Range(Primitive)
        if Range then
            Value.Range = Range.Range
            Tokens.Range = Range.Token
        end
    end

    local function WrapInOptional()
        -- ex: u8?
        local Optional = self:Optional()
        if Optional then
            Declaration = {
                Type = "Optional",
                Name = Name.Value,
                Value = { Of = Declaration },
                Tokens = {}
            } :: Optional
        end
    end

    WrapInOptional()

    -- ex: u8[][][]
    while (true) do
        local Array = self:Array()
        if Array then
            Declaration = {
                Type = "Array",
                Name = Name.Value,
                Value = {
                    Of = Declaration,
                    Range = Array.Range,
                },
                Tokens = {
                    Range = Array.Token
                }
            } :: Array
        end

        WrapInOptional()

        if Array == nil then
            break
        end
    end
    
    return Declaration
end

function Parser.Set(self: Parser, Name: Token): Set
    self:Consume("OpenBraces")

    local Values: {string} = {}
    while true do
        if self:TryConsume("CloseBraces") then
            break
        end

        local Token = self:ConsumeText(true, true)
        table.insert(Values, Token.Value)

        if self:TryConsume("CloseBraces") then
            break
        end

        self:Consume("Comma")
    end

    return {
        Type = "Set",
        Name = Name.Value,
        Value = {
            Values = Values,
        },
        Tokens = {}
    } :: Set
end

function Parser.Map(self: Parser, Name: Token): Map
    self:ConsumeAll("OpenBraces", "OpenBrackets")

    --> Errors
    local function ParseElement(): TypeNode
        local Token = self:Peek()
        local Declaration = self:Type(Name)
        if Declaration.Type == "Optional" then
            Error.new(Error.AnalyzeInvalidOptionalType, self.Source, "Invalid optional type", self.File)
                :Primary(Token, `Maps cannot have optionals as keys or values`)
            :Emit()
        end

        return Declaration
    end

    --> Parse key and value
    local Key = ParseElement()
    self:Consume("CloseBrackets")
    self:Consume("FieldAssign")

    local Value = ParseElement()
    self:Consume("CloseBraces")

    return {
        Type = "Map",
        Name = Name.Value,
        Value = {
            Values = {Key, Value}
        },
        Tokens = {}
    }
end

function Parser.Enum(self: Parser, Name: Token): Enum | TagEnum
    local Values: {string} = {}

    --> Is it a tagged enum?
    local Tag = self:TryConsume("String")
    if Tag then
        return self:TagEnum(Tag, Name)
    end

    self:Consume("OpenBraces")

    while true do
        if self:TryConsume("CloseBraces") then
            break
        end

        local Token = self:ConsumeText(true, true)
        table.insert(Values, Token.Value)

        if self:TryConsume("CloseBraces") then
            break
        end

        self:Consume("Comma")
    end

    return {
        Type = "Enum",
        Name = Name.Value,
        Value = { Values = Values } :: any,
        Tokens = {}
    }
end

function Parser.TagEnum(self: Parser, Tag: Token, Name: Token): TagEnum
    local Values: {Struct} = {}
    self:Consume("OpenBraces")

    while true do
        if self:TryConsume("CloseBraces") then
            break
        end

        local Token: Token
        
        if self:Peek().Type == "OpenBrackets" then
            self:Consume("OpenBrackets")
            Token = self:Consume("String")
            self:Consume("CloseBrackets")
        else
            Token = self:ConsumeText(true)
        end
        
        local Struct = self:Struct(Token)
        local Fields = Struct.Value.Values

        --> Don't allow tag field to be set
        for _, Field: TypeNode in Fields do
            if Field.Name == Tag.Value then
                Error.new(Error.AnalyzeReservedIdentifier, self.Source, `Enum tag used as field in variant`, self.File)
                    :Secondary(Token, `Used in variant`)
                    :Primary(Tag, `Enum tag`)
                :Emit()
            end
        end

        table.insert(Values, Struct)

        if self:TryConsume("CloseBraces") then
            break
        end

        self:Consume("Comma")
    end

    return {
        Type = "TagEnum",
        Name = Name.Value,
        Value = {
            Tag = Tag.Value,
            Values = Values
        },
        Tokens = {}
    }
end

function Parser.Tuple(self: Parser, Name: Token): Tuple
    local Values: {TypeNode} = {}
    self:Consume("OpenParentheses")

    while true do
        if self:TryConsume("CloseParentheses") then
            break
        end

        local Value = self:Type(Name)
        table.insert(Values, Value)

        if self:TryConsume("CloseParentheses") then
            break
        end

        self:Consume("Comma")
    end

    return {
        Type = "Tuple",
        Name = Name.Value,
        Value = {
            Values = Values,
        },
        Tokens = {}
    }
end

function Parser.Struct(self: Parser, Name: Token): Struct
    local Fields: {[string]: true} = {}
    local Values: {TypeNode} = {}
    self:Consume("OpenBraces")

    while true do
        if self:TryConsume("CloseBraces") then
            break
        end

        --> struct merging
        if self:TryConsume("Merge") then
            local Text = self:Peek()
            local Declaration = self:Declaration(Name)
            if Declaration.Type ~= "Struct" then
                error(Error.new(Error.AnalyzeReferenceInvalidType, self.Source, `Expected a struct to merge, got "{Declaration.Type}" instead`, self.File)
                    :Primary(Text, `Expected a "Struct", got "{Declaration.Type}" instead`)
                :Emit())
            end

            local Struct: Struct = Declaration :: Struct
            local StructValues = Struct.Value.Values
            for _, Field in StructValues do
                local FieldIdentifier = Field.Name
                if Fields[FieldIdentifier] then
                    error(Error.new(Error.AnalyzeDuplicateField, self.Source, `Merged struct contains a duplicate field`, self.File)
                        :Primary(Text, `Field "{FieldIdentifier}" already exists in struct`)
                    :Emit())
                end

                table.insert(Values, Field)
                Fields[FieldIdentifier] = true
            end
        else --> fields
            local Text: Token
            
            if self:Peek().Type == "OpenBrackets" then
                self:Consume("OpenBrackets")
                Text = self:Consume("String")
                self:Consume("CloseBrackets")
            else
                Text = self:ConsumeText(true)
            end
  
            if Fields[Text.Value] then
                error(Error.new(Error.AnalyzeDuplicateField, self.Source, `Duplicate field "{Text.Value}"`, self.File)
                    :Primary(Text, `Duplicate field`)
                :Emit())
            end
            
            self:Consume("FieldAssign")

            Fields[Text.Value] = true
            table.insert(Values, self:Type(Text))
        end

        if self:TryConsume("CloseBraces") then
            break
        end

        self:Consume("Comma")
    end

    return {
        Type = "Struct",
        Name = Name.Value,
        Value = {
            Values = Values,
        },
        Tokens = {}
    }
end

function Parser.Primitive(self: Parser, Name: Token): Primitive
    local Token = self:Consume("Primitive")

    local Class: string?;
    local Value = Token.Value
    local Primitive = PRIMITIVES[Value]

    if Value == "Instance" then
        local ClassToken = self:TryConsume("Class")
        Class = if ClassToken then string.sub(ClassToken.Value, 2, #ClassToken.Value - 1) else "Instance"
    end

    return {
        Type = "Primitive",
        Name = Name.Value,
        Value = {
            Class = Class,
            Primitive = Primitive
        },
        Tokens = {
            Primitive = Token
        }
    }
end

function Parser.Declaration(self: Parser, Name: Token): TypeNode
    local Token = self:ConsumeText()

    --> Generics reference resolution
    local Generics = self.Generics
    local List = (Generics and Generics.Keys[Token.Value])
    if List then
        local Generic: Generic = {
            __debug = os.clock(),
            Type = "Generic",
            Name = Name.Value,
            Value = { Generic = Token.Value },
            Tokens = {}
        }

        table.insert(List, Generic)
        return Generic
    end

    --> Normal reference resolution
    local Reference = self:Reference("Types", Token.Value) :: Reference
    if not Reference then
        error(Error.new(Error.AnalyzeUnknownReference, self.Source, `Unknown reference`, self.File)
            :Primary(Token, "Unknown reference")
        :Emit())
    end

    local To = Reference.To

    --> Need to use the new node name
    To = {
        Name = Name.Value,
        Type = To.Type :: any,
        Value = To.Value :: any,
        Tokens = To.Tokens :: any
    }
    
    if GENERICS_TYPES[To.Type] and To.Value.Generics then
        To = self:ReplaceGenerics(To)
    end

    return To
end

return Parser