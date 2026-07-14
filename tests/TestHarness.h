#pragma once

#include <functional>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace test {
struct Case { const char *name; std::function<void()> body; };
inline std::vector<Case> &cases() { static std::vector<Case> value; return value; }
struct Register { Register(const char *name, std::function<void()> body) { cases().push_back({name, std::move(body)}); } };
inline void require(bool condition, const std::string &message)
{
    if (!condition) throw std::runtime_error(message);
}
}

#define TEST(name) \
    static void name(); \
    static test::Register name ## _registration(#name, name); \
    static void name()
#define REQUIRE(condition) test::require((condition), #condition)
#define REQUIRE_EQUAL(actual, expected) test::require((actual) == (expected), std::string("Expected ") + #actual + " to equal " + #expected + ", observed '" + (actual) + "'.")

#ifdef RETRO_SPREADSHEET_TEST_MAIN
int main()
{
    int failures = 0;
    for (const auto &testCase : test::cases()) {
        try { testCase.body(); std::cout << "PASS: " << testCase.name << '\n'; }
        catch (const std::exception &error) { ++failures; std::cerr << "FAIL: " << testCase.name << "\n" << error.what() << '\n'; }
    }
    std::cout << test::cases().size() << " tests, " << failures << " failures\n";
    return failures == 0 ? 0 : 1;
}
#endif
