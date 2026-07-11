// İşlem ücret hesaplama birim testleri.
import 'package:flutter_test/flutter_test.dart';

import 'package:ozgurdent/core/constants/procedure_catalog.dart';
import 'package:ozgurdent/data/models/procedure_type.dart';

void main() {
  test('Yüzde modeli: hekim payı doğru hesaplanır', () {
    final dolgu = ProcedureCatalog.byId('dolgu')!;
    final shares = dolgu.computeShares(totalPrice: 1000);
    expect(shares.doctor, 300);
    expect(shares.clinic, 700);
  });

  test('Net modeli: implant sabit tutar', () {
    final implant = ProcedureCatalog.byId('implant')!;
    final shares = implant.computeShares(totalPrice: 5000);
    expect(shares.doctor, 1750);
    expect(shares.clinic, 3250);
  });

  test('Teknisyen düşülüp yüzde modeli', () {
    final zirkon = ProcedureCatalog.byId('kaplama_zirkon')!;
    final shares = zirkon.computeShares(totalPrice: 3000, labFee: 1000);
    expect(shares.doctor, 600); // (3000-1000)*0.30
    expect(shares.clinic, 2400);
  });

  test('Manuel yüzde override', () {
    final manual = ProcedureCatalog.manual;
    final shares =
        manual.computeShares(totalPrice: 2000, overridePercentage: 0.5);
    expect(shares.doctor, 1000);
    expect(shares.clinic, 1000);
  });

  test('Model anahtar dönüşümü', () {
    expect(PricingModelX.fromKey('net'), PricingModel.net);
    expect(PricingModelX.fromKey('bilinmeyen'), PricingModel.percentage);
  });
}
