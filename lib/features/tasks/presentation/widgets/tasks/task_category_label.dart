String taskCategoryLabel(String category) => switch (category) {
  'Work' => 'Công việc',
  'Personal' => 'Cá nhân',
  'Learning' => 'Học tập',
  _ => category,
};
