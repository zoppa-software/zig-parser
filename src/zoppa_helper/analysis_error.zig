///! analysis_error.zig
/// 解析エラーを表す列挙型です。
/// 字句解析エラー列挙型
pub const LexicalError = error{
    /// 単語解析エラー
    WordAnalysisError,
    /// ブロック解析エラー
    BlockAnalysisError,
    /// アンダーバーの連続エラー
    ConsecutiveUnderscoreError,
    /// 文字列リテラルが閉じられていない場合はエラー
    UnclosedStringLiteralError,
    /// ブロックが閉じられていない場合はエラー
    UnclosedBlockError,
    /// 無効なコマンドの場合はエラー
    InvalidCommandError,
    /// ワードのメモリ不足エラー
    OutOfMemoryWord,
    /// 展開式のメモリ不足エラー
    OutOfMemoryEmbeddedText,
};

/// 構文解析エラー列挙型
pub const ParserError = error{
    /// 式の生成に失敗した場合のエラー
    InvalidExpression,
    /// 式の生成に失敗した場合のエラー
    OutOfMemoryExpression,
    /// 一時的なメモリ不足エラー（数値）
    OutOfMemoryNumber,
    /// 一時的なメモリ不足エラー（文字列）
    OutOfMemoryString,
    /// 三項演算子の解析に失敗した場合のエラー
    TernaryOperatorParseFailed,
    /// 数値の解析に失敗した場合のエラー
    NumberParseFailed,
    /// 文字列の解析に失敗した場合のエラー
    StringParseFailed,
    /// サポートしていない埋め込み式
    UnsupportedEmbeddedExpression,
    /// 変数がセミコロンで区切られていない場合のエラー
    VariableNotSemicolonSeparated,
    /// 条件式の解析に失敗した場合のエラー
    ConditionParseFailed,
    /// 変数名が無効な場合のエラー
    InvalidVariableName,
    /// 変数の代入記号が無い場合のエラー
    VariableAssignmentMissing,
    /// 変数の値が無い場合のエラー
    VariableValueMissing,
    /// Ifブロックが閉じられていない場合のエラー
    IfBlockNotClosed,
    /// Ifブロックが開始されていない場合のエラー
    IfBlockNotStarted,
    /// Forブロックが閉じられていない場合のエラー
    ForBlockNotClosed,
    /// For構文の解析に失敗した場合のエラー
    ForParseFailed,
    /// Forブロックが開始されていない場合のエラー
    ForBlockNotStarted,
    /// Forブロックのコレクションが指定されていない場合のエラー
    InvalidForCollection,
    /// selectブロックが閉じられていない場合のエラー
    SelectBlockNotClosed,
    /// selectブロックが開始されていない場合のエラー
    SelectBlockNotStarted,
    /// selectブロックの評価式が指定されていない場合のエラー
    InvalidSelectExpression,
    /// selectブロックのcaseに値が指定されていない場合のエラー
    InvalidSelectCaseValue,
    /// selectブロックの解析に失敗した場合のエラー
    SelectParseFailed,
};

/// 変数エラー列挙型
pub const VariableError = error{
    /// メモリ不足エラー
    OutOfMemoryVariables,
    /// 変数の登録に失敗した場合のエラー
    RegistrationFailed,
    /// 変数の取得に失敗した場合のエラー
    RetrievalFailed,
    /// 変数の削除に失敗した場合のエラー
    UnregistFailed,
    /// 変数が存在しない場合のエラー
    NotFound,
    /// 変数階層の追加に失敗した場合のエラー
    AddVariableHierarchyFailed,
};

/// 値の操作に失敗した場合のエラー
pub const ValueError = error{
    /// 加算演算子がサポートされていない場合のエラー
    AddOperatorNotSupported,
    /// 減算演算子がサポートされていない場合のエラー
    SubtractOperatorNotSupported,
    /// 乗算演算子がサポートされていない場合のエラー
    MultiplyOperatorNotSupported,
    /// 除算演算子がサポートされていない場合のエラー
    DivideOperatorNotSupported,
    /// 等しい比較がサポートされていない場合のエラー
    EqualOperatorNotSupported,
    /// より大きい演算子がサポートされていない場合のエラー
    GreaterOperatorNotSupported,
    /// 以上演算子がサポートされていない場合のエラー
    GreaterEqualOperatorNotSupported,
    /// より小さい演算子がサポートされていない場合のエラー
    LessOperatorNotSupported,
    /// 以下演算子がサポートされていない場合のエラー
    LessEqualOperatorNotSupported,
    /// 等しくない演算子がサポートされていない場合のエラー
    NotEqualOperatorNotSupported,
    /// 論理積演算子がサポートされていない場合のエラー
    AndOperatorNotSupported,
    /// 論理和演算子がサポートされていない場合のエラー
    OrOperatorNotSupported,
    /// 論理排他的論理和演算子がサポートされていない場合のエラー
    XorOperatorNotSupported,
    /// 論理否定演算子がサポートされていない場合のエラー
    NotOperatorNotSupported,
    /// 数値変換に失敗した場合のエラー
    NumberConversionFailed,
    /// 文字列変換に失敗した場合のエラー
    StringConversionFailed,
    /// 0での除算が発生した場合のエラー
    DivisionByZero,
    /// 評価に失敗した場合のエラー
    EvaluationFailed,
    /// 単項演算子がサポートされていない場合のエラー
    UnaryOperatorNotSupported,
    /// 二項演算子がサポートされていない場合のエラー
    BinaryOperatorNotSupported,
    /// 前置き演算子がサポートされていない場合のエラー
    InvalidUnaryOperation,
    /// 識別子の解析に失敗した場合のエラー
    IdentifierParseFailed,
    /// 配列のメモリ不足エラー
    OutOfMemoryArray,
    /// 配列のインデックスが範囲外の場合のエラー
    ArrayIndexOutOfBounds,
    /// 配列のアクセスが無効な場合のエラー
    InvalidArrayAccess,
    /// 配列ではない値に対して配列操作を行った場合のエラー
    NotAnArray,
    /// 文字列に変換できない場合のエラー
    CannotConvertToString,
    /// 無効なIf文の場合のエラー
    InvalidIfStatement,

    /// 計算に失敗した場合のエラー
    CalculationFailed,
    /// 論理演算に失敗した場合のエラー
    LogicalOperationFailed,
    /// エスケープシーケンスの解析に失敗した場合のエラー
    EscapeSequenceParseFailed,
};

/// 解析エラーを表す列挙型
pub const AnalysisErrors = LexicalError || ParserError || VariableError || ValueError;
