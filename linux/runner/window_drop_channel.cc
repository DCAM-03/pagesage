#include "window_drop_channel.h"

#include <cstring>

#include "window_drop_paths.h"

namespace {

struct WindowDropState {
  FlMethodChannel* channel;
  bool enabled = false;
  bool dragging = false;

  ~WindowDropState() {
    fl_method_channel_set_method_call_handler(channel, nullptr, nullptr,
                                              nullptr);
    g_clear_object(&channel);
  }
};

void Notify(WindowDropState* state, const char* method,
            FlValue* args = nullptr) {
  fl_method_channel_invoke_method(state->channel, method, args, nullptr,
                                  nullptr, nullptr);
}

void SetDragging(WindowDropState* state, bool dragging) {
  if (state->dragging == dragging) {
    return;
  }
  state->dragging = dragging;
  Notify(state, dragging ? "dragEntered" : "dragExited");
}

gboolean DragMotion(GtkWidget* widget, GdkDragContext* context, gint, gint,
                    guint time, gpointer user_data) {
  auto* state = static_cast<WindowDropState*>(user_data);
  const bool accepted =
      state->enabled &&
      gtk_drag_dest_find_target(widget, context, nullptr) != GDK_NONE &&
      (gdk_drag_context_get_actions(context) & GDK_ACTION_COPY) != 0;
  gdk_drag_status(context,
                  accepted ? GDK_ACTION_COPY : static_cast<GdkDragAction>(0),
                  time);
  SetDragging(state, accepted);
  return TRUE;
}

void DragLeave(GtkWidget*, GdkDragContext*, guint, gpointer user_data) {
  auto* state = static_cast<WindowDropState*>(user_data);
  SetDragging(state, false);
}

gboolean DragDrop(GtkWidget* widget, GdkDragContext* context, gint, gint,
                  guint time, gpointer user_data) {
  auto* state = static_cast<WindowDropState*>(user_data);
  const GdkAtom target = gtk_drag_dest_find_target(widget, context, nullptr);
  if (!state->enabled || target == GDK_NONE) {
    return FALSE;
  }
  gtk_drag_get_data(widget, context, target, time);
  return TRUE;
}

void DragDataReceived(GtkWidget*, GdkDragContext* context, gint, gint,
                      GtkSelectionData* selection, guint, guint time,
                      gpointer user_data) {
  auto* state = static_cast<WindowDropState*>(user_data);
  SetDragging(state, false);
  const gint length = gtk_selection_data_get_length(selection);
  if (!state->enabled || length <= 0 || length > 1024 * 1024) {
    gtk_drag_finish(context, FALSE, FALSE, time);
    return;
  }
  const auto* bytes = gtk_selection_data_get_data(selection);
  const auto paths = LocalPathsFromUriList(
      std::string(reinterpret_cast<const char*>(bytes), length));
  g_autoptr(FlValue) values = fl_value_new_list();
  for (const auto& path : paths) {
    fl_value_append_take(values, fl_value_new_string(path.c_str()));
  }
  if (!paths.empty()) {
    Notify(state, "filesDropped", values);
  }
  gtk_drag_finish(context, !paths.empty(), FALSE, time);
}

void HandleMethodCall(FlMethodChannel*, FlMethodCall* call,
                      gpointer user_data) {
  auto* state = static_cast<WindowDropState*>(user_data);
  if (std::strcmp(fl_method_call_get_name(call), "setEnabled") != 0) {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  FlValue* args = fl_method_call_get_args(call);
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_BOOL) {
    fl_method_call_respond_error(call, "invalid-arguments",
                                 "Expected an enabled flag", nullptr, nullptr);
    return;
  }
  state->enabled = fl_value_get_bool(args);
  if (!state->enabled) {
    SetDragging(state, false);
  }
  fl_method_call_respond_success(call, nullptr, nullptr);
}

}

void RegisterWindowDropChannel(FlView* view) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "pagesage/window_drop", FL_METHOD_CODEC(codec));
  auto* state = new WindowDropState{channel};
  g_object_set_data_full(
      G_OBJECT(view), "pagesage-window-drop", state,
      [](gpointer data) { delete static_cast<WindowDropState*>(data); });
  fl_method_channel_set_method_call_handler(channel, HandleMethodCall, state,
                                            nullptr);
  GtkTargetEntry target = {const_cast<gchar*>("text/uri-list"), 0, 0};
  gtk_drag_dest_set(GTK_WIDGET(view), static_cast<GtkDestDefaults>(0), &target,
                    1, GDK_ACTION_COPY);
  g_signal_connect(view, "drag-motion", G_CALLBACK(DragMotion), state);
  g_signal_connect(view, "drag-leave", G_CALLBACK(DragLeave), state);
  g_signal_connect(view, "drag-drop", G_CALLBACK(DragDrop), state);
  g_signal_connect(view, "drag-data-received", G_CALLBACK(DragDataReceived),
                   state);
}
