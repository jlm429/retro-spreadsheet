#pragma once

#include <optional>
#include <string>

// Portable state for a single formula-bar edit. The UI owns keyboard focus and
// rendering, while this class keeps destination and reference selection separate.
class FormulaEditingSession
{
public:
    struct Cell { int row = 0; int column = 0; };
    struct Range { Cell first; Cell last; };

    void begin(Cell destination, const std::string &originalContents);
    void beginFunction(Cell destination, const std::string &originalContents, const std::string &functionName);
    bool isEditing() const;
    Cell destination() const;
    const std::string &originalContents() const;
    const std::string &draft() const;
    void setDraft(const std::string &value);
    void setReferenceRange(Range range);
    void insertReference(Range range, std::size_t insertionOffset);
    bool insertFunction(const std::string &functionName, std::size_t insertionOffset);
    std::optional<Range> referenceRange() const;
    std::string commit();
    std::string cancel();

    static std::string referenceText(Range range);
    static bool isSupportedFunction(const std::string &functionName);

private:
    bool editing_ = false;
    Cell destination_;
    std::optional<Range> referenceRange_;
    std::string originalContents_;
    std::string draft_;
};
