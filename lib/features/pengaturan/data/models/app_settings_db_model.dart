import '../../domain/entities/app_settings.dart';

class AppSettingsDbModel {
  const AppSettingsDbModel({
    required this.id,
    required this.currencyCode,
    required this.currencySymbol,
    required this.defaultTaxPercent,
    required this.stockAllowNegative,
    required this.autoPrintReceipt,
    required this.createdAt,
    required this.updatedAt,
    this.receiptHeader,
    this.receiptFooter,
  });

  final int id;
  final String currencyCode;
  final String currencySymbol;
  final double defaultTaxPercent;
  final bool stockAllowNegative;
  final bool autoPrintReceipt;
  final String createdAt;
  final String updatedAt;
  final String? receiptHeader;
  final String? receiptFooter;

  factory AppSettingsDbModel.fromMap(Map<String, Object?> map) {
    return AppSettingsDbModel(
      id: (map['id'] as num).toInt(),
      currencyCode: map['currency_code'] as String,
      currencySymbol: map['currency_symbol'] as String,
      defaultTaxPercent: (map['default_tax_percent'] as num).toDouble(),
      stockAllowNegative: (map['stock_allow_negative'] as num).toInt() == 1,
      autoPrintReceipt: ((map['auto_print_receipt'] as num?)?.toInt() ?? 1) == 1,
      receiptHeader: map['receipt_header'] as String?,
      receiptFooter: map['receipt_footer'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  factory AppSettingsDbModel.fromEntity(AppSettings entity) {
    final timestamp = DateTime.now().toIso8601String();
    return AppSettingsDbModel(
      id: 1,
      currencyCode: entity.currencyCode,
      currencySymbol: entity.currencySymbol,
      defaultTaxPercent: entity.defaultTaxPercent,
      stockAllowNegative: entity.stockAllowNegative,
      autoPrintReceipt: entity.autoPrintReceipt,
      receiptHeader: entity.receiptHeader,
      receiptFooter: entity.receiptFooter,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'currency_code': currencyCode,
      'currency_symbol': currencySymbol,
      'receipt_header': receiptHeader,
      'receipt_footer': receiptFooter,
      'default_tax_percent': defaultTaxPercent,
      'stock_allow_negative': stockAllowNegative ? 1 : 0,
      'auto_print_receipt': autoPrintReceipt ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  AppSettings toEntity() {
    return AppSettings(
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
      defaultTaxPercent: defaultTaxPercent,
      stockAllowNegative: stockAllowNegative,
      autoPrintReceipt: autoPrintReceipt,
      receiptHeader: receiptHeader,
      receiptFooter: receiptFooter,
    );
  }
}
