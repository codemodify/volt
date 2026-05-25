package main
import "log"

fun main() int {
    var s []int = new []int{10, 20, 30}
    log.Println("len=%d cap=%d", len(s), cap(s))   // 3, 3

    s = append(s, 40)
    log.Println("after append: len=%d cap=%d", len(s), cap(s))  // 4, 8 (grew to 8)

    s = append(s, 50)
    s = append(s, 60)
    s = append(s, 70)
    s = append(s, 80)
    log.Println("after 5 appends: len=%d cap=%d", len(s), cap(s))  // 8, 8

    s = append(s, 90)
    log.Println("after spillover: len=%d cap=%d", len(s), cap(s))  // 9, 16

    var sum int = 0
    for _, v := range s {
        sum = sum + v
    }
    log.Println("sum=%d", sum)            // 10+20+...+90 = 450

    if sum == 450 { ret 42 }
    ret 0
}
