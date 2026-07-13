import 'package:intl/intl.dart';

class WorkRequestCost {
  final String id;
  final String workRequestId;
  final double estimatedLaborCost;
  final double estimatedMaterialCost;
  final double actualLaborCost;
  final double actualMaterialCost;
  final double additionalExpenses;
  final double totalCost;
  final String? budgetSource;
  final String? purchaseReferenceNumber;
  final String? receiptAttachmentUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkRequestCost({
    required this.id,
    required this.workRequestId,
    this.estimatedLaborCost = 0.0,
    this.estimatedMaterialCost = 0.0,
    this.actualLaborCost = 0.0,
    this.actualMaterialCost = 0.0,
    this.additionalExpenses = 0.0,
    this.totalCost = 0.0,
    this.budgetSource,
    this.purchaseReferenceNumber,
    this.receiptAttachmentUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkRequestCost.fromJson(Map<String, dynamic> json) {
    return WorkRequestCost(
      id: json['id'] as String,
      workRequestId: json['work_request_id'] as String,
      estimatedLaborCost: (json['estimated_labor_cost'] as num?)?.toDouble() ?? 0.0,
      estimatedMaterialCost: (json['estimated_material_cost'] as num?)?.toDouble() ?? 0.0,
      actualLaborCost: (json['actual_labor_cost'] as num?)?.toDouble() ?? 0.0,
      actualMaterialCost: (json['actual_material_cost'] as num?)?.toDouble() ?? 0.0,
      additionalExpenses: (json['additional_expenses'] as num?)?.toDouble() ?? 0.0,
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0.0,
      budgetSource: json['budget_source'] as String?,
      purchaseReferenceNumber: json['purchase_reference_number'] as String?,
      receiptAttachmentUrl: json['receipt_attachment_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'work_request_id': workRequestId,
      'estimated_labor_cost': estimatedLaborCost,
      'estimated_material_cost': estimatedMaterialCost,
      'actual_labor_cost': actualLaborCost,
      'actual_material_cost': actualMaterialCost,
      'additional_expenses': additionalExpenses,
      'budget_source': budgetSource,
      'purchase_reference_number': purchaseReferenceNumber,
      'receipt_attachment_url': receiptAttachmentUrl,
    };
  }
}
