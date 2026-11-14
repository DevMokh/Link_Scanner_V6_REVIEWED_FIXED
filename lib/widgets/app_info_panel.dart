import 'package:flutter/material.dart';

import '../core/app_info.dart';
import '../core/theme.dart';
import 'brand_logo.dart';
import 'common.dart';

/// About panel with an in-app privacy disclosure consistent with PRIVACY.md.
class AppInfoPanel extends StatelessWidget {
  const AppInfoPanel({super.key});

  Future<void> _showPrivacy(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.backgroundSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: alpha(C.borderGlass, 0.82))),
        title: const Text('الخصوصية وتدفق البيانات'),
        content: const SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المعالجة المحلية', style: TextStyle(color: C.statusSafe, fontWeight: FontWeight.w800)),
                SizedBox(height: 5),
                Text('تحليل الروابط والرسائل وQR وOCR يتم على الجهاز. نصوص الرسائل والصور ونتائج OCR لا تُرسل إلى خادم.', style: TextStyle(color: C.textSecondary, height: 1.5, fontSize: 12)),
                SizedBox(height: 14),
                Text('الاتصالات الاختيارية', style: TextStyle(color: C.statusCyan, fontWeight: FontWeight.w800)),
                SizedBox(height: 5),
                Text('تتبّع التحويلات يتصل بالموقع نفسه بطلب HEAD وأحيانًا GET. RDAP يستقبل اسم الدومين المسجّل فقط. Google Safe Browsing يستقبل الرابط الكامل عند إعداد مفتاحه، وVirusTotal يستعلم عن معرّف الرابط. الفحص المتقدم يتطلب موافقتك.', style: TextStyle(color: C.textSecondary, height: 1.5, fontSize: 12)),
                SizedBox(height: 14),
                Text('التخزين على الجهاز', style: TextStyle(color: C.statusCyan, fontWeight: FontWeight.w800)),
                SizedBox(height: 5),
                Text('يُحفظ آخر 100 فحص. الروابط: اسم المضيف فقط مع الدرجة والوقت. الرسائل: طول النص وعدد الروابط فقط، دون حفظ محتوى الرسالة. مفاتيح API تحفظ في مخزن Android الآمن عندما يكون متاحًا.', style: TextStyle(color: C.textSecondary, height: 1.5, fontSize: 12)),
                SizedBox(height: 14),
                Text('الحافظة والخدمات', style: TextStyle(color: C.statusCyan, fontWeight: FontWeight.w800)),
                SizedBox(height: 5),
                Text('مراقبة الحافظة اختيارية ومقفولة افتراضيًا. لا توجد تحليلات استخدام أو إعلانات أو حسابات مستخدمين. فشل أي مصدر خارجي لا يُعامل على أنه نتيجة آمنة.', style: TextStyle(color: C.textSecondary, height: 1.5, fontSize: 12)),
                SizedBox(height: 14),
                Text('ملاحظة: هذا إفصاح تقني داخل التطبيق، وليس بديلاً عن مراجعة قانونية لسياسة الخصوصية قبل النشر التجاري.', style: TextStyle(color: C.statusWarning, height: 1.5, fontSize: 11.5)),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              LinkScannerLogo(size: 38, glowing: false),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kAppNameEn, style: TextStyle(color: C.textPrimary, fontWeight: FontWeight.w900, fontSize: 14)),
                    SizedBox(height: 3),
                    Text(kAppNameAr, style: TextStyle(color: C.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              StatusBadge(label: 'ENTERPRISE-GRADE', color: C.accentPrimary, dot: false),
            ],
          ),
          const SizedBox(height: 13),
          Divider(color: alpha(C.borderGlass, 0.65), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: Text('إصدار التطبيق', style: TextStyle(color: C.textSecondary, fontSize: 11))),
              MonospaceText('$kAppVersion+$kAppBuild', color: C.textPrimary, fontSize: 11),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showPrivacy(context),
            style: outlineButtonStyle(),
            icon: const Icon(Icons.privacy_tip_outlined, size: 17),
            label: const Text('عرض الخصوصية وتدفق البيانات'),
          ),
        ],
      ),
    );
  }
}
