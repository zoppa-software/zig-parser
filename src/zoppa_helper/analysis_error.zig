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
    /// 評価に失敗した場合のエラー
    EvaluationFailed,
    /// 単項演算子がサポートされていない場合のエラー
    UnaryOperatorNotSupported,
    /// 二項演算子がサポートされていない場合のエラー
    BinaryOperatorNotSupported,
    /// より大きい演算子がサポートされていない場合のエラー
    GreaterOperatorNotSupported,
    /// 以上演算子がサポートされていない場合のエラー
    GreaterEqualOperatorNotSupported,
    /// より小さい演算子がサポートされていない場合のエラー
    LessOperatorNotSupported,
    /// 以下演算子がサポートされていない場合のエラー
    LessEqualOperatorNotSupported,
    /// 等しい演算子がサポートされていない場合のエラー
    EqualOperatorNotSupported,
    /// 等しくない演算子がサポートされていない場合のエラー
    NotEqualOperatorNotSupported,
    /// 計算に失敗した場合のエラー
    CalculationFailed,
    /// 論理演算に失敗した場合のエラー
    LogicalOperationFailed,
};

/// 解析エラーを表す列挙型
pub const AnalysisErrors = LexicalError || ParserError;
