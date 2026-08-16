import Core
import Foundation

/// Hesap bakiyesi ve net varlık hesabı.
///
/// Transfer bir hesaptan çıkıp diğerine girer: net varlığa etkisi sıfırdır ama
/// hesap bazlı bakiyeyi iki yönde de değiştirir. Bu yüzden transfer, signedAmount
/// ile değil hesap kimliğine bakılarak işlenir.
public enum Balances {
    public static func balance(
        of account: AccountEntity,
        transactions: [TransactionEntity]
    ) -> Money {
        var total = account.openingBalance
        for transaction in transactions {
            switch transaction.direction {
            case .income where transaction.accountID == account.id:
                total = total + transaction.amount
            case .expense where transaction.accountID == account.id:
                total = total - transaction.amount
            case .transfer:
                if transaction.accountID == account.id {
                    total = total - transaction.amount
                } else if transaction.counterpartAccountID == account.id {
                    total = total + transaction.amount
                }
            default:
                continue
            }
        }
        return total
    }

    public static func netWorth(
        accounts: [AccountEntity],
        transactions: [TransactionEntity]
    ) -> Money {
        accounts.reduce(Money.zero) { running, account in
            running + balance(of: account, transactions: transactions)
        }
    }

    /// Hazır toplamlarla net varlık: satır listesi elde yokken kullanılır.
    /// Sonuç `netWorth(accounts:transactions:)` ile aynı, yol farklı — dashboard
    /// 10.000 satırı belleğe çekmek zorunda kalmasın diye.
    public static func netWorth(
        accounts: [AccountEntity],
        signedTotals: [UUID: Money]
    ) -> Money {
        accounts.reduce(Money.zero) { running, account in
            running + account.openingBalance + (signedTotals[account.id] ?? .zero)
        }
    }
}
