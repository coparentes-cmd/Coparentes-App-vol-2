enum UserRole { parentA, parentB, child, observer }

/// Mobile subscription / trial (F3). Web ignores for access.
enum BillingStatus { none, trialing, active, expired, canceled }

enum MessageTone { neutral, tense, aggressive, positive }

enum ExpenseStatus { pending, accepted, disputed, settled }

enum SwapStatus { pending, accepted, rejected, counterProposed }

enum EventType { school, medical, activity, handover, holiday, other }

enum ExportType { messages, calendar, finances, fullPack }

enum CustodySlotSource { schedule, exception, manual, swap }

enum CustodySchedulePattern { weekAlternating, everyOtherWeekend, customWeek }

enum CustodyScheduleStatus { draft, pendingApproval, active, superseded }

enum CustodyExceptionType { singleDay, range, holiday }

enum CustodyExceptionStatus { pending, accepted, rejected }
