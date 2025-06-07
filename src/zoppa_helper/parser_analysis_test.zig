const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Parser = @import("parser_analysis.zig").Parser;
const ParserError = @import("parser_analysis.zig").ParserError;
const String = @import("string.zig").String;

test "logcal test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("true and false");
    const expr1 = try parser.executes(&inp1);
    const ans1 = try expr1.get();
    try testing.expect(ans1.Boolean == false);

    const inp2 = String.newAllSlice("true and true");
    const expr2 = try parser.executes(&inp2);
    const ans2 = try expr2.get();
    try testing.expect(ans2.Boolean == true);

    const inp3 = String.newAllSlice("false and false");
    const expr3 = try parser.executes(&inp3);
    const ans3 = try expr3.get();
    try testing.expect(ans3.Boolean == false);

    const inp4 = String.newAllSlice("false and true");
    const expr4 = try parser.executes(&inp4);
    const ans4 = try expr4.get();
    try testing.expect(ans4.Boolean == false);

    const inp5 = String.newAllSlice("true or false");
    const expr5 = try parser.executes(&inp5);
    const ans5 = try expr5.get();
    try testing.expect(ans5.Boolean == true);

    const inp6 = String.newAllSlice("true or true");
    const expr6 = try parser.executes(&inp6);
    const ans6 = try expr6.get();
    try testing.expect(ans6.Boolean == true);

    const inp7 = String.newAllSlice("false or false");
    const expr7 = try parser.executes(&inp7);
    const ans7 = try expr7.get();
    try testing.expect(ans7.Boolean == false);

    const inp8 = String.newAllSlice("false or true");
    const expr8 = try parser.executes(&inp8);
    const ans8 = try expr8.get();
    try testing.expect(ans8.Boolean == true);

    const inp9 = String.newAllSlice("true xor false");
    const expr9 = try parser.executes(&inp9);
    const ans9 = try expr9.get();
    try testing.expect(ans9.Boolean == true);

    const inp10 = String.newAllSlice("true xor true");
    const expr10 = try parser.executes(&inp10);
    const ans10 = try expr10.get();
    try testing.expect(ans10.Boolean == false);

    const inp11 = String.newAllSlice("false xor false");
    const expr11 = try parser.executes(&inp11);
    const ans11 = try expr11.get();
    try testing.expect(ans11.Boolean == false);

    const inp12 = String.newAllSlice("false xor true");
    const expr12 = try parser.executes(&inp12);
    const ans12 = try expr12.get();
    try testing.expect(ans12.Boolean == true);
}

test "unary test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("+123.45");
    const expr1 = try parser.executes(&inp1);
    try testing.expectEqual(123.45, (try expr1.get()).Number);

    const inp2 = String.newAllSlice("-123.45");
    const expr2 = try parser.executes(&inp2);
    try testing.expectEqual(-123.45, (try expr2.get()).Number);

    const inp3 = String.newAllSlice("!true");
    const expr3 = try parser.executes(&inp3);
    try testing.expect((try expr3.get()).Boolean == false);

    const inp4 = String.newAllSlice("!false");
    const expr4 = try parser.executes(&inp4);
    try testing.expect((try expr4.get()).Boolean == true);

    const inp5 = String.newAllSlice("!123");
    const expr5 = try parser.executes(&inp5);
    _ = expr5.get() catch |err| {
        try testing.expect(err == ParserError.UnaryOperatorNotSupported);
    };
}

test "string literal test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp4 = String.newAllSlice("\"あいうえお\" + \"かきくけこ\"");
    const expr4 = try parser.executes(&inp4);
    const ans4 = try expr4.get();
    try testing.expectEqualStrings("あいうえおかきくけこ", ans4.String.raw());

    const inp3 = String.newAllSlice("'abcd' + 'efgh'");
    const expr3 = try parser.executes(&inp3);
    const ans3 = try expr3.get();
    try testing.expectEqualStrings("abcdefgh", ans3.String.raw());

    const inp1 = String.newAllSlice("'あいうえお'");
    const expr1 = try parser.executes(&inp1);
    const ans1 = try expr1.get();
    try testing.expectEqualStrings("あいうえお", ans1.String.raw());

    const inp2 = String.newAllSlice("\"あいうえお\"");
    const expr2 = try parser.executes(&inp2);
    const ans2 = try expr2.get();
    try testing.expectEqualStrings("あいうえお", ans2.String.raw());

    const inp1_escaped = String.newAllSlice("'あい\\'うえお'");
    const expr1_escaped = try parser.executes(&inp1_escaped);
    const ans1_escaped = try expr1_escaped.get();
    try testing.expectEqualStrings("あい'うえお", ans1_escaped.String.raw());

    const inp2_escaped = String.newAllSlice("\"あい\\\"うえお\"");
    const expr2_escaped = try parser.executes(&inp2_escaped);
    const ans2_escaped = try expr2_escaped.get();
    try testing.expectEqualStrings("あい\"うえお", ans2_escaped.String.raw());
}

test "parseParen test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp5 = String.newAllSlice("((\"Hello\" + \" \") + \"World\")");
    const expr5 = try parser.executes(&inp5);
    const ans5 = try expr5.get();
    try testing.expectEqualStrings("Hello World", ans5.String.raw());

    const inp1 = String.newAllSlice("(10 + 2) * 3");
    const expr1 = try parser.executes(&inp1);
    const ans1 = try expr1.get();
    try testing.expectEqual(36, ans1.Number);

    const inp2 = String.newAllSlice("((5 - 3) + 2) / 2");
    const expr2 = try parser.executes(&inp2);
    const ans2 = try expr2.get();
    try testing.expectEqual(2, ans2.Number);

    const inp3 = String.newAllSlice("(true or false) and (false xor true)");
    const expr3 = try parser.executes(&inp3);
    const ans3 = try expr3.get();
    try testing.expect(ans3.Boolean == true);

    const inp4 = String.newAllSlice("!(true and (false or true))");
    const expr4 = try parser.executes(&inp4);
    const ans4 = try expr4.get();
    try testing.expect(ans4.Boolean == false);
}

test "additionOrSubtraction test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("10 / 2 + 2 - 7");
    const expr1 = try parser.executes(&inp1);
    const ans1 = try expr1.get();
    try testing.expectEqual(0, ans1.Number);

    const inp2 = String.newAllSlice("10 + 2 - 7");
    const expr2 = try parser.executes(&inp2);
    const ans2 = try expr2.get();
    try testing.expectEqual(5, ans2.Number);

    const inp3 = String.newAllSlice("10 - 2 + 7");
    const expr3 = try parser.executes(&inp3);
    const ans3 = try expr3.get();
    try testing.expectEqual(15, ans3.Number);
}

test "multiplyOrDevision test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("12.5 * 2.0 / 5.0");
    const expr1 = try parser.executes(&inp1);
    const ans1 = try expr1.get();
    try testing.expectEqual(5, ans1.Number);

    const inp2 = String.newAllSlice("10 * 2 + 5 / 5");
    const expr2 = try parser.executes(&inp2);
    const ans2 = try expr2.get();
    try testing.expectEqual(21, ans2.Number);

    const inp3 = String.newAllSlice("10 / 2 * 5");
    const expr3 = try parser.executes(&inp3);
    const ans3 = try expr3.get();
    try testing.expectEqual(25, ans3.Number);

    const inp4 = String.newAllSlice("10 * 2 / 5");
    const expr4 = try parser.executes(&inp4);
    const ans4 = try expr4.get();
    try testing.expectEqual(4, ans4.Number);
}

test "factor test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("12345.6");
    const expr1 = try parser.executes(&inp1);
    const ans1 = try expr1.get();
    try testing.expectEqual(12345.6, ans1.Number);

    const inp2 = String.newAllSlice("+123.45");
    const expr2 = try parser.executes(&inp2);
    const ans2 = try expr2.get();
    try testing.expectEqual(123.45, ans2.Number);

    const inp3 = String.newAllSlice("-123.45");
    const expr3 = try parser.executes(&inp3);
    const ans3 = try expr3.get();
    try testing.expectEqual(-123.45, ans3.Number);

    const inp4 = String.newAllSlice("1_23.45");
    const expr4 = try parser.executes(&inp4);
    const ans4 = try expr4.get();
    try testing.expectEqual(123.45, ans4.Number);

    const inp5 = String.newAllSlice("true");
    const expr5 = try parser.executes(&inp5);
    const ans5 = try expr5.get();
    try testing.expect(ans5.Boolean == true);

    const inp6 = String.newAllSlice("false");
    const expr6 = try parser.executes(&inp6);
    const ans6 = try expr6.get();
    try testing.expect(ans6.Boolean == false);
}

test "equal, not equal test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("10 == 10");
    const expr1 = try parser.executes(&inp1);
    const ans1 = try expr1.get();
    try testing.expect(ans1.Boolean == true);

    const inp2 = String.newAllSlice("10 <> 20");
    const expr2 = try parser.executes(&inp2);
    const ans2 = try expr2.get();
    try testing.expect(ans2.Boolean == true);

    const inp3 = String.newAllSlice("10 == 20");
    const expr3 = try parser.executes(&inp3);
    const ans3 = try expr3.get();
    try testing.expect(ans3.Boolean == false);

    const inp4 = String.newAllSlice("10 <> 10");
    const expr4 = try parser.executes(&inp4);
    const ans4 = try expr4.get();
    try testing.expect(ans4.Boolean == false);

    const inp5 = String.newAllSlice("true == true");
    const expr5 = try parser.executes(&inp5);
    const ans5 = try expr5.get();
    try testing.expect(ans5.Boolean == true);

    const inp6 = String.newAllSlice("true <> false");
    const expr6 = try parser.executes(&inp6);
    const ans6 = try expr6.get();
    try testing.expect(ans6.Boolean == true);

    const inp7 = String.newAllSlice("false == false");
    const expr7 = try parser.executes(&inp7);
    const ans7 = try expr7.get();
    try testing.expect(ans7.Boolean == true);

    const inp8 = String.newAllSlice("false <> true");
    const expr8 = try parser.executes(&inp8);
    const ans8 = try expr8.get();
    try testing.expect(ans8.Boolean == true);

    const inp9 = String.newAllSlice("'abc' == 'abc'");
    const expr9 = try parser.executes(&inp9);
    const ans9 = try expr9.get();
    try testing.expect(ans9.Boolean == true);

    const inp10 = String.newAllSlice("'abc' <> 'def'");
    const expr10 = try parser.executes(&inp10);
    const ans10 = try expr10.get();
    try testing.expect(ans10.Boolean == true);

    const inp11 = String.newAllSlice("'abc' == 'def'");
    const expr11 = try parser.executes(&inp11);
    const ans11 = try expr11.get();
    try testing.expect(ans11.Boolean == false);

    const inp12 = String.newAllSlice("'abc' <> 'abc'");
    const expr12 = try parser.executes(&inp12);
    const ans12 = try expr12.get();
    try testing.expect(ans12.Boolean == false);
}

test "greater test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("10 > 5");
    const expr1 = try parser.executes(&inp1);
    const ans1 = try expr1.get();
    try testing.expect(ans1.Boolean == true);

    const inp2 = String.newAllSlice("5 > 10");
    const expr2 = try parser.executes(&inp2);
    const ans2 = try expr2.get();
    try testing.expect(ans2.Boolean == false);

    const inp3 = String.newAllSlice("10 > 10");
    const expr3 = try parser.executes(&inp3);
    const ans3 = try expr3.get();
    try testing.expect(ans3.Boolean == false);

    const inp4 = String.newAllSlice("5.1 > 5.1");
    const expr4 = try parser.executes(&inp4);
    const ans4 = try expr4.get();
    try testing.expect(ans4.Boolean == false);

    const inp5 = String.newAllSlice("10.1 > 5.1");
    const expr5 = try parser.executes(&inp5);
    const ans5 = try expr5.get();
    try testing.expect(ans5.Boolean == true);

    const inp6 = String.newAllSlice("5.1 > 10.1");
    const expr6 = try parser.executes(&inp6);
    const ans6 = try expr6.get();
    try testing.expect(ans6.Boolean == false);

    const inp7 = String.newAllSlice("'あいうえお' > 'あいうえか'");
    const expr7 = try parser.executes(&inp7);
    const ans7 = try expr7.get();
    try testing.expect(ans7.Boolean == false);

    const inp8 = String.newAllSlice("'あいうえか' > 'あいうえお'");
    const expr8 = try parser.executes(&inp8);
    const ans8 = try expr8.get();
    try testing.expect(ans8.Boolean == true);

    const inp9 = String.newAllSlice("'あいうえお' > 'あいうえお'");
    const expr9 = try parser.executes(&inp9);
    const ans9 = try expr9.get();
    try testing.expect(ans9.Boolean == false);

    const inp10 = String.newAllSlice("true > false");
    const expr10 = try parser.executes(&inp10);
    _ = expr10.get() catch |err| {
        try testing.expect(err == ParserError.GreaterOperatorNotSupported);
    };
}

test "greater or equal test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("10 >= 5");
    const expr1 = try parser.executes(&inp1);
    const ans1 = try expr1.get();
    try testing.expect(ans1.Boolean == true);

    const inp2 = String.newAllSlice("5 >= 10");
    const expr2 = try parser.executes(&inp2);
    const ans2 = try expr2.get();
    try testing.expect(ans2.Boolean == false);

    const inp3 = String.newAllSlice("10 >= 10");
    const expr3 = try parser.executes(&inp3);
    const ans3 = try expr3.get();
    try testing.expect(ans3.Boolean == true);

    const inp4 = String.newAllSlice("5.1 >= 5.1");
    const expr4 = try parser.executes(&inp4);
    const ans4 = try expr4.get();
    try testing.expect(ans4.Boolean == true);

    const inp5 = String.newAllSlice("10.1 >= 5.1");
    const expr5 = try parser.executes(&inp5);
    const ans5 = try expr5.get();
    try testing.expect(ans5.Boolean == true);

    const inp6 = String.newAllSlice("5.1 >= 10.1");
    const expr6 = try parser.executes(&inp6);
    const ans6 = try expr6.get();
    try testing.expect(ans6.Boolean == false);

    const inp7 = String.newAllSlice("'あいうえお' >= 'あいうえか'");
    const expr7 = try parser.executes(&inp7);
    const ans7 = try expr7.get();
    try testing.expect(ans7.Boolean == false);

    const inp8 = String.newAllSlice("'あいうえか' >= 'あいうえお'");
    const expr8 = try parser.executes(&inp8);
    const ans8 = try expr8.get();
    try testing.expect(ans8.Boolean == true);

    const inp9 = String.newAllSlice("'あいうえお' >= 'あいうえお'");
    const expr9 = try parser.executes(&inp9);
    const ans9 = try expr9.get();
    try testing.expect(ans9.Boolean == true);

    const inp10 = String.newAllSlice("true >= false");
    const expr10 = try parser.executes(&inp10);
    _ = expr10.get() catch |err| {
        try testing.expect(err == ParserError.GreaterEqualOperatorNotSupported);
    };
}

test "less test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("5 < 10");
    const expr1 = try parser.executes(&inp1);
    const ans1 = try expr1.get();
    try testing.expect(ans1.Boolean == true);

    const inp2 = String.newAllSlice("10 < 5");
    const expr2 = try parser.executes(&inp2);
    const ans2 = try expr2.get();
    try testing.expect(ans2.Boolean == false);

    const inp3 = String.newAllSlice("10 < 10");
    const expr3 = try parser.executes(&inp3);
    const ans3 = try expr3.get();
    try testing.expect(ans3.Boolean == false);

    const inp4 = String.newAllSlice("5.1 < 5.1");
    const expr4 = try parser.executes(&inp4);
    const ans4 = try expr4.get();
    try testing.expect(ans4.Boolean == false);

    const inp5 = String.newAllSlice("5.1 < 10.1");
    const expr5 = try parser.executes(&inp5);
    const ans5 = try expr5.get();
    try testing.expect(ans5.Boolean == true);

    const inp6 = String.newAllSlice("10.1 < 5.1");
    const expr6 = try parser.executes(&inp6);
    const ans6 = try expr6.get();
    try testing.expect(ans6.Boolean == false);

    const inp7 = String.newAllSlice("'あいうえか' < 'あいうえお'");
    const expr7 = try parser.executes(&inp7);
    const ans7 = try expr7.get();
    try testing.expect(ans7.Boolean == false);

    const inp8 = String.newAllSlice("'あいうえお' < 'あいうえか'");
    const expr8 = try parser.executes(&inp8);
    const ans8 = try expr8.get();
    try testing.expect(ans8.Boolean == true);

    const inp9 = String.newAllSlice("'あいうえお' < 'あいうえお'");
    const expr9 = try parser.executes(&inp9);
    const ans9 = try expr9.get();
    try testing.expect(ans9.Boolean == false);

    const inp10 = String.newAllSlice("true < false");
    const expr10 = try parser.executes(&inp10);
    _ = expr10.get() catch |err| {
        try testing.expect(err == ParserError.LessOperatorNotSupported);
    };
}

test "less or equal test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("5 <= 10");
    const expr1 = try parser.executes(&inp1);
    const ans1 = try expr1.get();
    try testing.expect(ans1.Boolean == true);

    const inp2 = String.newAllSlice("10 <= 5");
    const expr2 = try parser.executes(&inp2);
    const ans2 = try expr2.get();
    try testing.expect(ans2.Boolean == false);

    const inp3 = String.newAllSlice("10 <= 10");
    const expr3 = try parser.executes(&inp3);
    const ans3 = try expr3.get();
    try testing.expect(ans3.Boolean == true);

    const inp4 = String.newAllSlice("5 <= 5");
    const expr4 = try parser.executes(&inp4);
    const ans4 = try expr4.get();
    try testing.expect(ans4.Boolean == true);

    const inp5 = String.newAllSlice("5.5 <= 10.5");
    const expr5 = try parser.executes(&inp5);
    const ans5 = try expr5.get();
    try testing.expect(ans5.Boolean == true);

    const inp6 = String.newAllSlice("10.5 <= 5.5");
    const expr6 = try parser.executes(&inp6);
    const ans6 = try expr6.get();
    try testing.expect(ans6.Boolean == false);

    const inp7 = String.newAllSlice("'あいうえか' <= 'あいうえお'");
    const expr7 = try parser.executes(&inp7);
    const ans7 = try expr7.get();
    try testing.expect(ans7.Boolean == false);

    const inp8 = String.newAllSlice("'あいうえお' <= 'あいうえか'");
    const expr8 = try parser.executes(&inp8);
    const ans8 = try expr8.get();
    try testing.expect(ans8.Boolean == true);

    const inp9 = String.newAllSlice("'あいうえお' <= 'あいうえお'");
    const expr9 = try parser.executes(&inp9);
    const ans9 = try expr9.get();
    try testing.expect(ans9.Boolean == true);

    const inp10 = String.newAllSlice("true <= false");
    const expr10 = try parser.executes(&inp10);
    _ = expr10.get() catch |err| {
        try testing.expect(err == ParserError.LessEqualOperatorNotSupported);
    };
}

test "ternaryOperatorParser test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("true ? 1 : 0");
    const expr1 = try parser.executes(&inp1);
    const ans1 = try expr1.get();
    try testing.expectEqual(1, ans1.Number);

    const inp2 = String.newAllSlice("false ? 1 : 0");
    const expr2 = try parser.executes(&inp2);
    const ans2 = try expr2.get();
    try testing.expectEqual(0, ans2.Number);

    const inp3 = String.newAllSlice("true ? 'yes' : 'no'");
    const expr3 = try parser.executes(&inp3);
    const ans3 = try expr3.get();
    try testing.expectEqualStrings("yes", ans3.String.raw());

    const inp4 = String.newAllSlice("false ? 'yes' : 'no'");
    const expr4 = try parser.executes(&inp4);
    const ans4 = try expr4.get();
    try testing.expectEqualStrings("no", ans4.String.raw());

    const inp5 = String.newAllSlice("1 < 2 ? 'small' : 'large'");
    const expr5 = try parser.executes(&inp5);
    const ans5 = try expr5.get();
    try testing.expectEqualStrings("small", ans5.String.raw());

    const inp6 = String.newAllSlice("2 < 1 ? 'small' : 'large'");
    const expr6 = try parser.executes(&inp6);
    const ans6 = try expr6.get();
    try testing.expectEqualStrings("large", ans6.String.raw());
}

test "translate test" {
    const allocator = std.testing.allocator;
    var parser = try Parser().init(allocator);
    defer parser.deinit();

    const inp1 = String.newAllSlice("Hello, #{'World \\{\\}'}!");
    const expr1 = try parser.translate(&inp1);
    const ans1 = try expr1.get();
    try testing.expectEqualStrings("Hello, World {}!", ans1.String.raw());

    const inp2 = String.newAllSlice("1.1 + 1 = #{1.1 + 1}");
    const expr2 = try parser.translate(&inp2);
    const ans2 = try expr2.get();
    try testing.expectEqualStrings("1.1 + 1 = 2.1", ans2.String.raw());
}
