import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spelling_bee_practice/domain/entities/practice_session.dart';
import 'package:spelling_bee_practice/presentation/bloc/practice_bloc.dart';
import 'package:spelling_bee_practice/presentation/bloc/practice_event.dart';
import 'package:spelling_bee_practice/presentation/bloc/practice_state.dart';
import 'package:spelling_bee_practice/presentation/widgets/shared/word_card_practice.dart';
import 'package:spelling_bee_practice/presentation/screens/home/random_practice_view.dart'; // Importa la vista

class PracticeTab extends StatefulWidget {
  final PracticeSession? selectedSession;

  const PracticeTab({super.key, this.selectedSession});

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab> {
  @override
  Widget build(BuildContext context) {
    String title = widget.selectedSession != null
        ? 'Sesión: ${widget.selectedSession!.name}'
        : 'Práctica';
    return BlocProvider(
      create: (context) => PracticeBloc()..add(LoadWordsEvent(widget.selectedSession)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: <Widget>[
            BlocBuilder<PracticeBloc, PracticeState>(
              builder: (context, state) {
                if (state is PracticeLoaded) {
                  return PopupMenuButton<String>(
                    onSelected: (String newValue) {
                      context
                          .read<PracticeBloc>()
                          .add(ChangeFilterEvent(newValue));
                    },
                    itemBuilder: (BuildContext context) {
                      return <String>[...state.lists]
                          .map<PopupMenuEntry<String>>((String listName) {
                        return PopupMenuItem<String>(
                          value: listName,
                          child: Text(listName),
                        );
                      }).toList();
                    },
                    child: Chip(
                      label: Text(state.filter),
                      avatar: const Icon(Icons.filter_list),
                    ),
                  );
                } else {
                  return const SizedBox
                      .shrink(); // No mostrar el filtro si no esta cargado
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
              return Stack(children: [
                ListView.builder(
                  itemCount: state.words.length,
                  itemBuilder: (context, index) {
                    final word = state.words[index];
                    return StatefulBuilder(
                      builder: (context, setState) {
                        return WordCardPractice(
                          key: ValueKey(word.id),
                          word: word,
                          onDelete: () {
                            if (widget.selectedSession != null) {
                              context
                                  .read<PracticeBloc>()
                                  .add(RemoveWordEvent(word, widget.selectedSession!));
                            }
                          },
                          onRecordPracticeCallback: (word, isCorrect) {
                            context.read<PracticeBloc>().add(
                                RecordPracticeEvent(
                                    word, isCorrect, widget.selectedSession));
                            setState(() {});
                          },
                          selectedSession: widget.selectedSession,
                          showRemoveButton: widget.selectedSession != null,
                        );
                      },
                    );
                  },
                ),
                Positioned(
                    bottom: 40,
                    right: 40,
                    child: FloatingActionButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => RandomPracticeView(
                                  words: state.words, filter: state.filter)),
                        ).then((_) {
                          if (mounted) {
                            // Recargar palabras al regresar
                            context
                                .read<PracticeBloc>()
                                .add(LoadWordsEvent(widget.selectedSession));
                          }
                        });
                      },
                      shape: CircleBorder( // Forma redonda
                        side: BorderSide(color: Colors.yellowAccent, width: 6.0), // Contorno amarillo
                      ),
                      backgroundColor: Colors.white,
                      elevation: 0,
                      focusElevation: 0,
                      hoverElevation:0,
                      highlightElevation:0,
                      disabledElevation: 0,
                      child: Image.asset('assets/icon/icon.png', width: 40, height: 40),
                    )),
              ]);
            } else if (state is PracticeError) {
              return Center(child: Text(state.message));
            } else {
              return const Center(
                  child: Text("Seleccione una sesión o lista."));
            }
          },
        ),
      ),
    );
  }
}
