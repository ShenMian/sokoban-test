use godot::prelude::*;
use soukoban::direction;

#[derive(GodotConvert, Var, Export, Default, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum Direction {
    #[default]
    Up,
    Down,
    Left,
    Right,
}

impl From<Direction> for direction::Direction {
    fn from(direction: Direction) -> Self {
        match direction {
            Direction::Up => direction::Direction::Up,
            Direction::Down => direction::Direction::Down,
            Direction::Left => direction::Direction::Left,
            Direction::Right => direction::Direction::Right,
        }
    }
}
