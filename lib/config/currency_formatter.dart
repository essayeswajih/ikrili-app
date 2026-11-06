import 'package:intl/intl.dart';

class CurrencyFormatter {
  const CurrencyFormatter._();

  static String format(num amount, String currency, {String locale = 'en'}) {
    final symbols = {'DT': 'DT', 'EUR': '€', 'USD': '\$'};
    final symbol = symbols[currency] ?? currency;
    return NumberFormat.currency(name: currency, symbol: symbol, decimalDigits: 2, locale: locale).format(amount);
  }
}
