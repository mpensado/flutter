import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spelling_bee_practice/domain/entities/practice_session.dart';
import 'package:spelling_bee_practice/presentation/bloc/practice_bloc.dart';
import 'package:spelling_bee_practice/presentation/widgets/shared/word_card_practice.dart';

class PracticeTab extends StatelessWidget {
  final PracticeSession? selectedSession;

  const PracticeTab({Key? key, this.selectedSession}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String title = selectedSession != null
        ? 'Sesión: ${selectedSession!.name}'
        : 'Práctica';
    return BlocProvider(
      create: (context) => PracticeBloc()..add(LoadWordsEvent(selectedSession)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: <Widget>[
            BlocBuilder<PracticeBloc, PracticeState>(
              builder: (context, state) {
                if (state is PracticeLoaded)
                {
                  return DropdownButton<String>(
                    value: state.filter,
                    icon: const Icon(Icons.filter_list),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        context
                            .read<PracticeBloc>()
                            .add(ChangeFilterEvent(newValue));
                      }
                    },
                    items: <String>['Todo', 'Errores', ...state.lists]
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  );
                } else {
                  return const SizedBox.shrink(); // No mostrar el filtro si no esta cargado
                }
              },
            ),
          ],
        ),
        body: BlocBuilder<PracticeBloc, PracticeState>(
          builder: (context, state) {
            if (state is PracticeLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is PracticeLoaded) {
              return ListView.builder(
                itemCount: state.words.length,
                itemBuilder: (context, index) {
                  final word = state.words[index];
                  return StatefulBuilder(
                    builder: (context, setState) {
                      return WordCardPractice(
                        key: ValueKey(word.id),
                        word: word,
                        onDelete: () {
                          if (selectedSession != null) {
                            context
                                .read<PracticeBloc>()
                                .add(RemoveWordEvent(word, selectedSession!));
                          }
                        },
                        onRecordPracticeCallback: (word, isCorrect) {
                          context.read<PracticeBloc>().add(
                              RecordPracticeEvent(
                                  word, isCorrect, selectedSession));
                          setState(() {});
                        },
                        selectedSession: selectedSession,
                        showRemoveButton: selectedSession != null,
                      );
                    },
                  );
                },
              );
            } else if (state is PracticeError) {
              return Center(child: Text(state.message));
            } else {
              return const Center(child: Text("Seleccione una sesión o lista."));
            }
          },
        ),
      ),
    );
  }
}