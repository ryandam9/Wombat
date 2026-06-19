import 'package:flutter_test/flutter_test.dart';
import 'package:route/models/openrouter_model.dart';

void main() {
  group('OpenRouterModel', () {
    test('parses id, name, context and pricing', () {
      final model = OpenRouterModel.fromJson({
        'id': 'openai/gpt-4o',
        'name': 'GPT-4o',
        'description': 'desc',
        'context_length': 128000,
        'pricing': {'prompt': '0.000005', 'completion': '0.000015'},
      });

      expect(model.id, 'openai/gpt-4o');
      expect(model.name, 'GPT-4o');
      expect(model.description, 'desc');
      expect(model.contextLength, 128000);
      expect(model.promptPrice, 0.000005);
      expect(model.completionPrice, 0.000015);
      expect(model.isFree, isFalse);
      expect(model.vendor, 'openai');
    });

    test('detects free models', () {
      final free = OpenRouterModel.fromJson({
        'id': 'meta/free',
        'name': 'Free',
        'pricing': {'prompt': '0', 'completion': '0'},
      });
      expect(free.isFree, isTrue);
    });

    test('treats absent pricing as free', () {
      final model = OpenRouterModel.fromJson({'id': 'x/y', 'name': 'Y'});
      expect(model.promptPrice, isNull);
      expect(model.isFree, isTrue);
    });

    test('falls back to id when name is empty or missing', () {
      final emptyName =
          OpenRouterModel.fromJson({'id': 'a/b', 'name': '   '});
      expect(emptyName.name, 'a/b');

      final noName = OpenRouterModel.fromJson({'id': 'c/d'});
      expect(noName.name, 'c/d');
    });

    test('parses input/output modalities and capability flags', () {
      final model = OpenRouterModel.fromJson({
        'id': 'g/gemini-image',
        'name': 'Gemini Image',
        'architecture': {
          'input_modalities': ['text', 'image'],
          'output_modalities': ['text', 'image'],
        },
      });
      expect(model.supportsImageInput, isTrue);
      expect(model.supportsImageOutput, isTrue);

      final textOnly = OpenRouterModel.fromJson({'id': 'a/b', 'name': 'B'});
      expect(textOnly.supportsImageOutput, isFalse);
      expect(textOnly.outputModalities, ['text']);
    });

    test('vendor is "other" when id has no slash', () {
      final model = OpenRouterModel.fromJson({'id': 'solo', 'name': 'Solo'});
      expect(model.vendor, 'other');
    });

    test('handles numeric pricing values', () {
      final model = OpenRouterModel.fromJson({
        'id': 'x/y',
        'name': 'Y',
        'pricing': {'prompt': 0.001, 'completion': 0.002},
      });
      expect(model.promptPrice, 0.001);
      expect(model.completionPrice, 0.002);
    });
  });
}
